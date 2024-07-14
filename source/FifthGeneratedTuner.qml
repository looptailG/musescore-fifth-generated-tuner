/*
	A Musescore plugin for tuning a score based on the specified fifth size.
	Copyright (C) 2024 Alessandro Culatti

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import QtQuick 2.2
import QtQuick.Controls 2.15
import FileIO 3.0
import MuseScore 3.0
import "libs/DateUtils.js" as DateUtils
import "libs/StringUtils.js" as StringUtils
import "libs/TuningUtils.js" as TuningUtils

MuseScore
{
	title: "Fifth Generated Tuner";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	categoryCode: "playback";
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	version: "1.3.0-alpha";
	
	pluginType: "dialog";
	width: 470;
	height: 760;
	
	property variant settings: {};
	
	// List containing some commonly installed monospaced fonts.
	property var preferredFonts: ["Consolas", "Courier New", "Menlo", "Monaco", "DejaVu Sans Mono", "Ubuntu Mono"];
	// Variable containing the name of an installed monospaced font from the
	// previous list.
	property var monospacedFont: null;
	
	// Size of the buttons of the pre-set tuning systems.
	property int buttonWidth: 100;
	property int buttonHeight: 40;
	
	// String variables containing the sizes of the smallest and largest fifths,
	// rounded to 1 digit after the decimal point.
	property var smallestFifthString: StringUtils.roundToOneDecimalDigit(TuningUtils.SMALLEST_DIATONIC_FIFTH);
	property var largestFifthString: StringUtils.roundToOneDecimalDigit(TuningUtils.LARGEST_DIATONIC_FIFTH);
	// Difference in cents between a 12EDO fifth and the fifh selected by the
	// user.
	property var fifthDeviation;
	
	// Reference note, which has a tuning offset of zero.
	property var referenceNoteName;
	property var referenceNoteAccidental;
	property var referenceNote;
	
	// Maximum number of custom tuning systems.
	property var maxCustomTunings: 5;
	
	// Amount of notes which were tuned successfully.
	property var tunedNotes: 0;
	// Total amount of notes encountered in the portion of the score to tune.
	property var totalNotes: 0;
	
	Dialog
	{
		id: fifthSizeDialog;
		title: "WARNING - Fifth Size";
		standardButtons: Dialog.Yes | Dialog.No;
		
		contentItem: Column
		{
			Label
			{
				id: fifthSizeDialogText;
				text: "";
			}
		}
		
		onAccepted:
		{
			try
			{
				tuneNotes();
			}
			catch (error)
			{
				outputMessageArea.text = error;
			}
		}
	}
	
	Dialog
	{
		id: newCustomTuningDialog;
		title: "New Custom Tuning";
		standardButtons: Dialog.Ok | Dialog.Cancel;
		
		contentItem: Column
		{
			Label
			{
				text: "Tuning Name";
			}
			TextField
			{
				id: customTuningNameField;
			}
			
			Label
			{
				text: "Fifth Size";
			}
			TextField
			{
				id: customTuningFifthSizeField;
				font.family: monospacedFont;
			}
		}
		
		onAccepted:
		{
			try
			{
				newCustomTuning(customTuningNameField.text, customTuningFifthSizeField.text.replace(",", "."));
				loadCustomTunings();
			}
			catch (error)
			{
				outputMessageArea.text = error;
			}
		}
	}
	
	Dialog
	{
		id: deleteCustomDialog;
		title: "Delete Custom Tunings";
		standardButtons: Dialog.Ok | Dialog.Cancel;
		
		contentItem: Column
		{
			CheckBox
			{
				id: deleteCustomCheckbox0;
				text: "";
				visible: false;
			}
			
			CheckBox
			{
				id: deleteCustomCheckbox1;
				text: "";
				visible: false;
			}
			
			CheckBox
			{
				id: deleteCustomCheckbox2;
				text: "";
				visible: false;
			}
			
			CheckBox
			{
				id: deleteCustomCheckbox3;
				text: "";
				visible: false;
			}
			
			CheckBox
			{
				id: deleteCustomCheckbox4;
				text: "";
				visible: false;
			}
		}
		
		onAccepted:
		{
			try
			{
				var selectedCustomTunings = [];
				for (var i = 0; i < customTuningChoices.count; i++)
				{
					var currentTuning = customTuningChoices.get(i);
					if (currentTuning.checked)
					{
						selectedCustomTunings.push(currentTuning.text);
					}
				}
				deleteCustomTunings(selectedCustomTunings);
				loadCustomTunings();
			}
			catch (error)
			{
				outputMessageArea.text = error.toString();
			}
		}
	}
	
	FileIO
	{
		id: logger;
		source: Qt.resolvedUrl(".").toString().substring(8) + "logs/" + DateUtils.getFileDateTime() + "_log.txt";
		property var logMessages: "";
		property var currentLogLevel: 2;
		property variant logLevels:
		{
			0: " | TRACE   | ",
			1: " | INFO    | ",
			2: " | WARNING | ",
			3: " | ERROR   | ",
			4: " | FATAL   | ",
		}
		
		function log(message, logLevel)
		{
			if (logLevel === undefined)
			{
				logLevel = 1;
			}
			
			if (logLevel >= currentLogLevel)
			{
				logMessages += DateUtils.getRFC3339DateTime() + logLevels[logLevel] + message + "\n";
			}
		}
		
		function trace(message)
		{
			log(message, 0);
		}
		
		function warning(message)
		{
			log(message, 2);
		}
		
		function error(message)
		{
			log(message, 3);
		}
		
		function fatal(message)
		{
			log(message, 4);
		}
		
		function writeLogMessages()
		{
			if (logMessages != "")
			{
				write(logMessages);
			}
		}
	}
	
	FileIO
	{
		id: customTuningsIO;
		source: Qt.resolvedUrl(".").substring(8) + "CustomTunings.tsv";
		
		onError:
		{
			outputMessageArea.text = msg;
		}
	}
	
	FileIO
	{
		id: settingsIO;
		source: Qt.resolvedUrl(".").substring(8) + "Settings.tsv";
		
		onError:
		{
			outputMessageArea.text = msg;
		}
	}
	
	Rectangle
	{
		anchors.fill: parent;
		
/*		Row
		{
			x: 10;
			y: 10;
			spacing: 10;
			
			Text
			{
				text: "Fifth size in cents:";
				font.pixelSize: 20;
			}
			
			TextField
			{
				placeholderText: qsTr(smallestFifthString + " - " + largestFifthString);
				font.family: monospacedFont;
				id: fifthSizeField;
				width: 150;
				height: 30;
			}
			
			Button
			{
				width: 100;
				height: 30;
				text: "Tune";
				onClicked:
				{
					try
					{
						// Read the input fifth size.
						var fifthSize = parseFloat(fifthSizeField.text);
						if (isNaN(fifthSize))
						{
							if (fifthSizeField.text == "")
							{
								throw "Empty input field.";
							}
							else
							{
								throw "Cannot convert to number the input fifth size: " + fifthSizeField.text;
							}
						}
						else
						{
							fifthDeviation = TuningUtils.DEFAULT_FIFTH - fifthSize;
							
							if (fifthSize < TuningUtils.SMALLEST_DIATONIC_FIFTH)
							{
								fifthSizeDialogText.text = "The input fifth is smaller than " + smallestFifthString + " ¢, which is the smallest fifth for which standard notation makes sense.\nThe plugin can work anyway, but it could produce some counterintuitive results.\nTune the score anyway?";
								fifthSizeDialogText.open();
							}
							else if (fifthSize > TuningUtils.LARGEST_DIATONIC_FIFTH)
							{
								fifthSizeDialogText.text = "The input fifth is larger than " + largestFifthString + " ¢, which is the largest fifth for which standard notation makes sense.\nThe plugin can work anyway, but it could produce some counterintuitive results.\nTune the score anyway?";
								fifthSizeDialogText.open();
							}
							else
							{
								tuneNotes();
							}
						}
					}
					catch (error)
					{
						outputMessageArea.text = error;
					}
				}
			}
		}
		
		Row
		{
			x: 10;
			y: 50;
			spacing: 10;
			
			Text
			{
				text: "Reference note:";
				font.pixelSize: 15;
			}
			
			ComboBox
			{
				id: referenceNoteNameComboBox;
				model: ["A", "B", "C", "D", "E", "F", "G"];
				width: 50;
				onActivated:
				{
					try
					{
						settings["ReferenceNoteNameIndex"] = referenceNoteNameComboBox.currentIndex;
						writeSettings();
						referenceNoteName = referenceNoteNameComboBox.currentText;
						referenceNote = referenceNoteName + referenceNoteAccidental;
					}
					catch (error)
					{
						outputMessageArea.text = error.toString();
					}
				}
			}
			
			ComboBox
			{
				id: referenceNoteAccidentalComboBox;
				model: ["bbb", "bb", "b", "", "#", "x", "#x"];
				width: 50;
				onActivated:
				{
					try
					{
						settings["ReferenceNoteAccidentalIndex"] = referenceNoteAccidentalComboBox.currentIndex;
						writeSettings();
						referenceNoteAccidental = referenceNoteAccidentalComboBox.currentText;
						referenceNote = referenceNoteName + referenceNoteAccidental;
					}
					catch (error)
					{
						outputMessageArea.text = error.toString();
					}
				}
			}
		}
		
		Row
		{
			x: 10;
			y: 100;
			spacing: 50;
			
			Column
			{
				spacing: 10;
				
				Text
				{
					text: "EDOs";
					font.pixelSize: 15;
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "5";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 5 * 3;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "7";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 7 * 4;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "12";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.DEFAULT_FIFTH;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "17";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 17 * 10;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "19";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 19 * 11;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "26";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 26 * 15;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "29";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 29 * 17;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "31";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 31 * 18;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "41";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 41 * 24;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "43";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 43 * 25;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "50";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 50 * 29;
					}
				}
			}
			
			Column
			{
				spacing: 10;
				
				Text
				{
					text: "Meantones";
					font.pixelSize: 15;
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/3 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 3;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "2/7 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 2 / 7;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "7/26 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 7 / 26;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/4 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 4;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "2/9 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 2 / 9;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/5 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 5;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/6 Comma";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 6;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Golden";
					onClicked:
					{
						fifthSizeField.text = 600.0 / 11 * (15 - Math.sqrt(5));
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Tungsten";
					onClicked:
					{
						fifthSizeField.text = 600.0 * (Math.sqrt(10) - 2);
					}
				}
			}
			
			Column
			{
				spacing: 10;
				
				Text
				{
					text: "Others";
					font.pixelSize: 15;
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Pythagorean";
					onClicked:
					{
						fifthSizeField.text = TuningUtils.JUST_FIFTH;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "";
					property var customFifthSize0;
					id: custom0;
					visible: false;
					onClicked:
					{
						fifthSizeField.text = customFifthSize0;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "";
					property var customFifthSize1;
					id: custom1;
					visible: false;
					onClicked:
					{
						fifthSizeField.text = customFifthSize1;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "";
					property var customFifthSize2;
					id: custom2;
					visible: false;
					onClicked:
					{
						fifthSizeField.text = customFifthSize2;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "";
					property var customFifthSize3;
					id: custom3;
					visible: false;
					onClicked:
					{
						fifthSizeField.text = customFifthSize3;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "";
					property var customFifthSize4;
					id: custom4;
					visible: false;
					onClicked:
					{
						fifthSizeField.text = customFifthSize4;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Add Custom";
					font.italic: true;
					id: addCustom;
					onClicked:
					{
						try
						{
							newCustomTuningDialog.open();
						}
						catch (error)
						{
							outputMessageArea.text = error;
						}
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Delete Custom";
					font.italic: true;
					id: deleteCustom;
					onClicked:
					{
						try
						{
							// Populate the checkbox with every custom tuning.
							customTuningChoices.clear();
							var fileContent = customTuningsIO.read().split("\n");
							for (var i = 0; i < fileContent.length; i++)
							{
								if (fileContent[i].trim() != "")
								{
									var rowData = StringUtils.parseTsvRow(fileContent[i]);
									customTuningChoices.append({ text: rowData[0], checked: false });
								}
							}
							deleteCustomDialog.open();
						}
						catch (error)
						{
							outputMessageArea.text = error.toString();
						}
					}
				}
			}
		}
		
		Row
		{
			x: 10;
			y: 700;
			spacing: 10;
			
			TextArea
			{
				id: outputMessageArea;
				text: "";
				font.family: monospacedFont;
				readOnly: true;
				width: 450;
				height: 50;
			}
		}*/
	}
	
	/**
	 * Tune the notes in the selection, or the entire score if nothing is
	 * selected, according to the selected fifth size.
	 */
/*	function tuneNotes()
	{
		curScore.startCmd();
	
		// Calculate the portion of the score to tune.
		var cursor = curScore.newCursor();
		var startStaff;
		var endStaff;
		var startTick;
		var endTick;
		cursor.rewind(Cursor.SELECTION_START);
		if (!cursor.segment)
		{
			// Tune the entire score.
			startStaff = 0;
			endStaff = curScore.nstaves - 1;
			startTick = 0;
			endTick = curScore.lastSegment.tick + 1;
		}
		else
		{
			// Tune only the selection.
			startStaff = cursor.staffIdx;
			startTick = cursor.tick;
			cursor.rewind(Cursor.SELECTION_END);
			endStaff = cursor.staffIdx;
			if (cursor.tick == 0)
			{
				// If the selection includes the last measure of the score,
				// .rewind() overflows and goes back to tick 0.
				endTick = curScore.lastSegment.tick + 1;
			}
			else
			{
				endTick = cursor.tick;
			}
		}
		
		// Loop on the portion of the score to tune.
		for (var staff = startStaff; staff <= endStaff; staff++)
		{
			for (var voice = 0; voice < 4; voice++)
			{
				cursor.voice = voice;
				cursor.staffIdx = staff;
				cursor.rewindToTick(startTick);
				
				while (cursor.segment && (cursor.tick < endTick))
				{
					// Tune notes.
					if (cursor.element)
					{
						if (cursor.element.type == Element.CHORD)
						{
							var graceChords = cursor.element.graceNotes;
							for (var i = 0; i < graceChords.length; i++)
							{
								var notes = graceChords[i].notes;
								for (var j = 0; j < notes.length; j++)
								{
									notes[j].tuning = -TuningUtils.circleOfFifthsDistance(notes[j], referenceNote) * fifthDeviation;
								}
							}
							
							var notes = cursor.element.notes;
							for (var i = 0; i < notes.length; i++)
							{
								notes[i].tuning = -TuningUtils.circleOfFifthsDistance(notes[i], referenceNote) * fifthDeviation;
							}
						}
					}
					
					cursor.next();
				}
			}
		}
		
		curScore.endCmd();
		
		quit();
	}*/
	
	Component.onCompleted:
	{
/*		// Read settings file.
		settings = {};
		try
		{
			var settingsFileContents = settingsIO.read().split("\n");
			for (var i = 0; i < settingsFileContents.length; i++)
			{
				if (settingsFileContents[i].trim() != "")
				{
					var rowData = StringUtils.parseTsvRow(settingsFileContents[i]);
					settings[rowData[0]] = rowData[1];
				}
			}
		}
		catch (error)
		{
			outputMessageArea.text = error.toString();
		}
		
		// Initialise monospaced font.
		for (var i = 0; i < preferredFonts.length; i++)
		{
			if (Qt.fontFamilies().indexOf(preferredFonts[i]) !== -1)
			{
				monospacedFont = preferredFonts[i];
				break;
			}
		}
		
		// Initialise reference note.
		referenceNoteNameComboBox.currentIndex = settings["ReferenceNoteNameIndex"];
		referenceNoteName = referenceNoteNameComboBox.currentText;
		referenceNoteAccidentalComboBox.currentIndex = settings["ReferenceNoteAccidentalIndex"];
		referenceNoteAccidental = referenceNoteAccidentalComboBox.currentText;
		referenceNote = referenceNoteName + referenceNoteAccidental;
		
		// Initialise output message area.
		outputMessageArea.text = "-- Fifth Generated Tuner -- Version " + version + " --";
		
		// Initialise custom tunings buttons.
		try
		{
			loadCustomTunings();
		}
		catch (error)
		{
			outputMessageArea.error;
		}*/
	}
	
	onRun:
	{
/*		if (typeof curScore === "undefined")
		{
			quit();
		}*/
	}
	
	/**
	 * Write the contents of settings to the settings file.
	 */
	function writeSettings()
	{
		var fileContent = "";
		for (var i = 0; i < Object.keys(settings).length; i++)
		{
			var key = Object.keys(settings)[i].toString();
			var value = settings[key].toString();
			fileContent += StringUtils.formatForTsv(key) + "\t" + StringUtils.formatForTsv(value) + "\n";
		}
		settingsIO.write(fileContent);
	}
	
	/**
	 * Load the custom tunings from the cunfiguration file, and set the
	 * properties of the custom tunings buttons.
	 */
	function loadCustomTunings()
	{
		custom0.visible = false;
		custom1.visible = false;
		custom2.visible = false;
		custom3.visible = false;
		custom4.visible = false;
	
		var customTuningCounter = 0;
		var fileContent = customTuningsIO.read().split("\n");
		for (var i = 0; i < fileContent.length; i++)
		{
			if (fileContent[i].trim() != "")
			{
				var rowData = StringUtils.parseTsvRow(fileContent[i]);
				switch (customTuningCounter)
				{
					case 0:
						custom0.text = rowData[0];
						custom0.customFifthSize0 = rowData[1];
						custom0.visible = true;
						break;
					
					case 1:
						custom1.text = rowData[0];
						custom1.customFifthSize1 = rowData[1];
						custom1.visible = true;
						break;
					
					case 2:
						custom2.text = rowData[0];
						custom2.customFifthSize2 = rowData[1];
						custom2.visible = true;
						break;
					
					case 3:
						custom3.text = rowData[0];
						custom3.customFifthSize3 = rowData[1];
						custom3.visible = true;
						break;
					
					case 4:
						custom4.text = rowData[0];
						custom4.customFifthSize4 = rowData[1];
						custom4.visible = true;
						break;
				}
				
				customTuningCounter++;
				if (customTuningCounter >= maxCustomTunings)
				{
					break;
				}
			}
		}
		
		if (customTuningCounter >= maxCustomTunings)
		{
			addCustom.enabled = false;
		}
		else
		{
			addCustom.enabled = true;
		}
		
		if (customTuningCounter >= 1)
		{
			deleteCustom.enabled = true;
		}
		else
		{
			deleteCustom.enabled = false;
		}
	}
	
	/**
	 * Add the input custom tuning to the configuration file.
	 */
	function newCustomTuning(tuningName, customFifthSize)
	{
		tuningName = StringUtils.formatForTsv(tuningName.trim());
		customFifthSize = ("" + customFifthSize).trim();
		if ((customFifthSize == "") || isNaN(customFifthSize))
		{
			throw "Invalid custom fifth size: " + customFifthSize;
		}
		
		var fileContent = customTuningsIO.read();
		fileContent += "\n" + tuningName + "\t" + customFifthSize;
		customTuningsIO.write(StringUtils.removeEmptyRows(fileContent));
	}
	
	/**
	 * Delete the tunings with the input names from the configuration file.
	 */
	function deleteCustomTunings(tuningsToDelete)
	{
		var fileContent = customTuningsIO.read().split("\n");
		for (var i = 0; i < tuningsToDelete.length; i++)
		{
			var tuningToDelete = tuningsToDelete[i];
			for (var j = fileContent.length - 1; j >= 0; j--)
			{
				var currentTuningName = StringUtils.parseTsvRow(fileContent[j])[0];
				if (currentTuningName == tuningToDelete)
				{
					fileContent.splice(j, 1);
				}
			}
		}
		customTuningsIO.write(StringUtils.removeEmptyRows(fileContent.join("\n")));
	}
}
