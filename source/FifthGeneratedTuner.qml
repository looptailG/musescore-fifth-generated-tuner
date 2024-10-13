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
import "libs/AccidentalUtils.js" as AccidentalUtils
import "libs/DateUtils.js" as DateUtils
import "libs/NoteUtils.js" as NoteUtils
import "libs/StringUtils.js" as StringUtils
import "libs/TuningUtils.js" as TuningUtils

MuseScore
{
	title: "Fifth Generated Tuner";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	categoryCode: "playback";
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	version: "1.3.1";
	
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
	
	// Amount of notes which were tuned successfully.
	property var tunedNotes: 0;
	// Total amount of notes encountered in the portion of the score to tune.
	property var totalNotes: 0;
	
	// Maximum number of custom tuning systems.
	property var maxCustomTunings: 5;
	
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
				width: 460;
				wrapMode: Text.Wrap;
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
				logger.error(error.toString());
			}
		}
		
		onRejected:
		{
			logger.log("Tuning canceled.");
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
				outputMessageArea.text = error.toString();
				logger.error(error.toString());
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
				if (deleteCustomCheckbox0.checked)
				{
					selectedCustomTunings.push(deleteCustomCheckbox0.text);
				}
				if (deleteCustomCheckbox1.checked)
				{
					selectedCustomTunings.push(deleteCustomCheckbox1.text);
				}
				if (deleteCustomCheckbox2.checked)
				{
					selectedCustomTunings.push(deleteCustomCheckbox2.text);
				}
				if (deleteCustomCheckbox3.checked)
				{
					selectedCustomTunings.push(deleteCustomCheckbox3.text);
				}
				if (deleteCustomCheckbox4.checked)
				{
					selectedCustomTunings.push(deleteCustomCheckbox4.text);
				}
				deleteCustomTunings(selectedCustomTunings);
				loadCustomTunings();
			}
			catch (error)
			{
				outputMessageArea.text = error.toString();
				logger.error(error.toString());
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
				write(logMessages);
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
	}
	
	FileIO
	{
		id: customTuningsIO;
		source: Qt.resolvedUrl(".").toString().substring(8) + "CustomTunings.tsv";
		
		onError:
		{
			outputMessageArea.text = msg;
			logger.error(msg);
		}
	}
	
	FileIO
	{
		id: settingsIO;
		source: Qt.resolvedUrl(".").toString().substring(8) + "Settings.tsv";
		
		onError:
		{
			outputMessageArea.text = msg;
			logger.error(msg);
		}
	}
	
	Rectangle
	{
		anchors.fill: parent;
		
		Column
		{
			x: 10;
			y: 10;
			spacing: 10;
			
			Row
			{
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
								logger.log("Fifth size: " + fifthSize);
								fifthDeviation = TuningUtils.DEFAULT_FIFTH - fifthSize;
								logger.log("Fifth deviation: " + fifthDeviation);
								
								if (fifthSize < TuningUtils.SMALLEST_DIATONIC_FIFTH)
								{
									logger.warning("Fifth smaller than the smallest diatonic fifth: " + fifthSize);
									fifthSizeDialogText.text = "The input fifth is smaller than " + smallestFifthString + " ¢, which is the smallest fifth for which standard notation makes sense.\nThe plugin can work anyway, but it could produce some counterintuitive results.\nTune the score anyway?";
									fifthSizeDialog.open();
								}
								else if (fifthSize > TuningUtils.LARGEST_DIATONIC_FIFTH)
								{
									logger.warning("Fifth larger than the largest diatonic fifth: " + fifthSize);
									fifthSizeDialogText.text = "The input fifth is larger than " + largestFifthString + " ¢, which is the largest fifth for which standard notation makes sense.\nThe plugin can work anyway, but it could produce some counterintuitive results.\nTune the score anyway?";
									fifthSizeDialog.open();
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
							logger.error(error);
						}
					}
				}
			}
		
			Row
			{
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
							referenceNote = referenceNoteName + ((referenceNoteAccidental == "-") ? "" : referenceNoteAccidental);
							logger.log("Reference note changed to: " + referenceNote);
						}
						catch (error)
						{
							outputMessageArea.text = error.toString();
							logger.error(error);
						}
					}
				}
				
				ComboBox
				{
					id: referenceNoteAccidentalComboBox;
					model: ["bbb", "bb", "b", "-", "#", "x", "#x"];
					width: 50;
					onActivated:
					{
						try
						{
							settings["ReferenceNoteAccidentalIndex"] = referenceNoteAccidentalComboBox.currentIndex;
							writeSettings();
							referenceNoteAccidental = referenceNoteAccidentalComboBox.currentText;
							referenceNote = referenceNoteName + ((referenceNoteAccidental == "-") ? "" : referenceNoteAccidental);
							logger.log("Reference note changed to: " + referenceNote);
						}
						catch (error)
						{
							outputMessageArea.text = error.toString();
							logger.error(error);
						}
					}
				}
			}
			
			Row
			{
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
			}
		}
		

	}
	
	/**
	 * Tune the notes in the selection, or the entire score if nothing is
	 * selected, according to the selected fifth size.
	 */
	function tuneNotes()
	{
		try
		{
			logger.log("Tuning notes.");
			
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
				logger.log("Tuning the entire score.");
				startStaff = 0;
				endStaff = curScore.nstaves - 1;
				startTick = 0;
				endTick = curScore.lastSegment.tick + 1;
			}
			else
			{
				logger.log("Tuning only the current selection.");
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
				logger.trace("Tuning only ticks: " + startTick + " - " + endTick);
				logger.trace("Tuning only staffs: " + startStaff + " - " + endStaff);
			}
			
			// Loop on the portion of the score to tune.
			for (var staff = startStaff; staff <= endStaff; staff++)
			{
				for (var voice = 0; voice < 4; voice++)
				{
					logger.log("Tuning Staff: " + staff + "; Voice: " + voice);
					
					cursor.voice = voice;
					cursor.staffIdx = staff;
					cursor.rewindToTick(startTick);
					
					while (cursor.segment && (cursor.tick < endTick))
					{
						// Tune notes.
						if (cursor.element && (cursor.element.type == Element.CHORD))
						{
							var graceChords = cursor.element.graceNotes;
							for (var i = 0; i < graceChords.length; i++)
							{
								var notes = graceChords[i].notes;
								for (var j = 0; j < notes.length; j++)
								{
									try
									{
										notes[j].tuning = calculateTuningOffset(notes[j]);
									}
									catch (error)
									{
										logger.error(error);
									}
								}
							}
							
							var notes = cursor.element.notes;
							for (var i = 0; i < notes.length; i++)
							{
								try
								{
									notes[i].tuning = calculateTuningOffset(notes[i]);
								}
								catch (error)
								{
									logger.error(error);
								}
							}
						}
						
						cursor.next();
					}
				}
			}
			
			logger.log("Notes tuned: " + tunedNotes + " / " + totalNotes);
			
			curScore.endCmd();
		}
		catch (error)
		{
			logger.fatal(error);
		}
		finally
		{
			quit();
		}
	}
	
	/**
	 * Returns the amount of cents necessary to tune the input note to 31EDO.
	 */
	function calculateTuningOffset(note)
	{
		totalNotes += 1;
		
		logger.trace("Tuning note: " + NoteUtils.getNoteLetter(note) + " " + AccidentalUtils.getAccidentalName(note) + " " + NoteUtils.getOctave(note));
		
		try
		{
			var tuningOffset = -TuningUtils.circleOfFifthsDistance(note, referenceNote) * fifthDeviation;
			tunedNotes += 1;
			logger.trace("Tuning offset: " + tuningOffset);
			return tuningOffset;
		}
		catch (error)
		{
			logger.error(error);
			// Leave the tuning of the input note unchanged.
			return note.tuning;
		}
	}
	
	Component.onCompleted:
	{
		try
		{
			// Read settings file.
			settings = {};
			var settingsFileContents = settingsIO.read().split("\n");
			for (var i = 0; i < settingsFileContents.length; i++)
			{
				if (settingsFileContents[i].trim() != "")
				{
					var rowData = StringUtils.parseTsvRow(settingsFileContents[i]);
					settings[rowData[0]] = rowData[1];
				}
			}
			logger.currentLogLevel = parseInt(settings["LogLevel"]);
			
			logger.log("-- Fifth Generated Tuner -- Version " + version + " --");
			logger.log("Log level set to: " + logger.currentLogLevel);
			
			// Initialise monospaced font.
			for (var i = 0; i < preferredFonts.length; i++)
			{
				if (Qt.fontFamilies().indexOf(preferredFonts[i]) !== -1)
				{
					monospacedFont = preferredFonts[i];
					logger.log("Monospaced font set to: " + monospacedFont);
					break;
				}
			}
			
			// Initialise reference note.
			referenceNoteNameComboBox.currentIndex = settings["ReferenceNoteNameIndex"];
			referenceNoteName = referenceNoteNameComboBox.currentText;
			referenceNoteAccidentalComboBox.currentIndex = settings["ReferenceNoteAccidentalIndex"];
			referenceNoteAccidental = referenceNoteAccidentalComboBox.currentText;
			referenceNote = referenceNoteName + ((referenceNoteAccidental == "-") ? "" : referenceNoteAccidental);
			logger.log("Reference note set to: " + referenceNote);
			
			// Initialise output message area.
			outputMessageArea.text = "-- Fifth Generated Tuner -- Version " + version + " --";
		
			// Initialise custom tunings buttons.
			loadCustomTunings();
		}
		catch (error)
		{
			logger.fatal(error.toString());
		}
	}
	
	onRun:
	{
		if (typeof curScore === "undefined")
		{
			quit();
		}
	}
	
	/**
	 * Write the contents of settings to the settings file.
	 */
	function writeSettings()
	{
		logger.log("Updating settings file.");
	
		var fileContent = "";
		for (var i = 0; i < Object.keys(settings).length; i++)
		{
			var key = Object.keys(settings)[i].toString();
			var value = settings[key].toString();
			fileContent += StringUtils.formatForTsv(key) + "\t" + StringUtils.formatForTsv(value) + "\n";
		}
		settingsIO.write(fileContent);
		
		logger.log("Settings file updated successfully.");
	}
	
	/**
	 * Load the custom tunings from the cunfiguration file, and set the
	 * properties of the custom tunings buttons.
	 */
	function loadCustomTunings()
	{
		logger.log("Loading custom tunings.");
	
		custom0.visible = false;
		custom1.visible = false;
		custom2.visible = false;
		custom3.visible = false;
		custom4.visible = false;
		
		deleteCustomCheckbox0.visible = false;
		deleteCustomCheckbox1.visible = false;
		deleteCustomCheckbox2.visible = false;
		deleteCustomCheckbox3.visible = false;
		deleteCustomCheckbox4.visible = false;
	
		var customTuningCounter = 0;
		var fileContent = customTuningsIO.read().split("\n");
		for (var i = 0; i < fileContent.length; i++)
		{
			if (fileContent[i].trim() != "")
			{
				var rowData = StringUtils.parseTsvRow(fileContent[i]);
				logger.trace("Name: " + rowData[0] + "; Fifth Size: " + rowData[1]);
				switch (customTuningCounter)
				{
					case 0:
						custom0.text = rowData[0];
						custom0.customFifthSize0 = rowData[1];
						custom0.visible = true;
						deleteCustomCheckbox0.text = rowData[0];
						deleteCustomCheckbox0.visible = true;
						break;
					
					case 1:
						custom1.text = rowData[0];
						custom1.customFifthSize1 = rowData[1];
						custom1.visible = true;
						deleteCustomCheckbox1.text = rowData[0];
						deleteCustomCheckbox1.visible = true;
						break;
					
					case 2:
						custom2.text = rowData[0];
						custom2.customFifthSize2 = rowData[1];
						custom2.visible = true;
						deleteCustomCheckbox2.text = rowData[0];
						deleteCustomCheckbox2.visible = true;
						break;
					
					case 3:
						custom3.text = rowData[0];
						custom3.customFifthSize3 = rowData[1];
						custom3.visible = true;
						deleteCustomCheckbox3.text = rowData[0];
						deleteCustomCheckbox3.visible = true;
						break;
					
					case 4:
						custom4.text = rowData[0];
						custom4.customFifthSize4 = rowData[1];
						custom4.visible = true;
						deleteCustomCheckbox4.text = rowData[0];
						deleteCustomCheckbox4.visible = true;
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
		
		logger.log("Custom tunings loaded successfully.");
	}
	
	/**
	 * Add the input custom tuning to the configuration file.
	 */
	function newCustomTuning(tuningName, customFifthSize)
	{
		logger.log("Adding a new custom tuning");
		
		tuningName = StringUtils.formatForTsv(tuningName.trim());
		customFifthSize = ("" + customFifthSize).trim();
		logger.trace("Name: " + tuningName + "; Size: " + customFifthSize);
		if ((customFifthSize == "") || isNaN(customFifthSize))
		{
			throw "Invalid custom fifth size: " + customFifthSize;
		}
		
		var fileContent = customTuningsIO.read();
		fileContent += "\n" + tuningName + "\t" + customFifthSize;
		customTuningsIO.write(StringUtils.removeEmptyRows(fileContent));
		
		logger.log("New custom tuning added successfully.");
	}
	
	/**
	 * Delete the tunings with the input names from the configuration file.
	 */
	function deleteCustomTunings(tuningsToDelete)
	{
		logger.log("Deleting selected custom tunings.");
		
		var fileContent = customTuningsIO.read().split("\n");
		for (var i = 0; i < tuningsToDelete.length; i++)
		{
			var tuningToDelete = tuningsToDelete[i];
			logger.trace("Deleting tuning: " + tuningToDelete);
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
		
		logger.log("Tuning deleted successfully.");
	}
}
