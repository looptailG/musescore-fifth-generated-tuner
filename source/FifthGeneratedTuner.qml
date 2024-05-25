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

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Styles 1.3
import QtQuick.Dialogs 1.1
import FileIO 3.0
import MuseScore 3.0

MuseScore
{
	title: qsTr("Fifth Generated Tuner");
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	categoryCode: "playback";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	version: "1.1.0-alpha";
	
	pluginType: "dialog";
	width: 470;
	height: 735;
	
	// List containing some commonly installed monospaced fonts.
	property var preferredFonts: ["Consolas", "Courier New", "Menlo", "Monaco", "DejaVu Sans Mono", "Ubuntu Mono"];
	// Variable containing the name of an installed monospaced font from the
	// previous list.
	property var monospacedFont: null;
	
	// Size of the buttons of the pre-set tuning systems.
	property int buttonWidth: 100;
	property int buttonHeight: 40;
	
	// Size in cents of a justly tuned perfect fifth.
	property var justFifth: 1200.0 * Math.log2(3 / 2);
	// Size in cents of a 12EDO perfect fifth.
	property var defaultFifth: 700.0;
	// Size in cents of the syntonic comma.
	property var syntonicComma: 1200.0 * Math.log2(81 / 80);
	
	// Size in cents of the smallest fifth after which the standard notation
	// cease to make sense.  It's equal to the 7EDO fifth.
	property var smallestFifth: 1200.0 / 7 * 4;
	// Size in censt of the largest fifth after which the standard notation
	// cease to make sense.  It's equal to the 5EDO fifth.
	property var largestFifth: 1200.0 / 5 * 3;
	// String variables containing the sizes of the smallest and largest fifths,
	// rounded to 1 digit after the decimal point.
	property var smallestFifthString: roundToOneDecimalDigit(smallestFifth);
	property var largestFifthString: roundToOneDecimalDigit(largestFifth);
	// Size in cents of the fifth selected by the user.
	property var fifthSize;
	// Difference in cents between a 12EDO fifth and the fifh selected by the
	// user.
	property var fifthDeviation;
	
	// Offset in cents between the notes in 12EDO and their counterpart in other
	// tuning systems.
	property variant baseNotesOffset:
	{
		"C": 2 * fifthDeviation,
		"D": 0,
		"E": -2 * fifthDeviation,
		"F": 3 * fifthDeviation,
		"G": 1 * fifthDeviation,
		"A": -1 * fifthDeviation,
		"B": -3 * fifthDeviation,
	};
	
	ListModel
	{
		id: customTuningChoices;
	}
	
	MessageDialog
	{
		id: fifthSizeDialog;
		title: "WARNING - Fifth Size";
		text: "";
		standardButtons: StandardButton.Yes | StandardButton.No;
		
		onYes:
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
				text: "Custom Tuning Name";
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
			}
		}
		
		onAccepted:
		{
			try
			{
				newCustomTuning(customTuningNameField.text, customTuningFifthSizeField.text);
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
			spacing: 10;
			padding: 10;
		
			Repeater
			{
				model: customTuningChoices;
				
				CheckBox
				{
					text: model.text;
					checked: model.checked;
					onCheckedChanged: model.checked = checked;
				}
			}
		}
		
		onAccepted:
		{
			
		}
	}
	
	FileIO
	{
		id: "customTuningsIO";
		source: Qt.resolvedUrl(".").substring(8) + "CustomTunings.tsv";
		
		onError:
		{
			outputMessageArea.text = msg;
		}
	}
	
	Rectangle
	{
		anchors.fill: parent;
		
		Row
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
						fifthSize = parseFloat(fifthSizeField.text);
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
							fifthDeviation = defaultFifth - fifthSize;
							
							if (fifthSize < smallestFifth)
							{
								fifthSizeDialog.text = "The input fifth is smaller than " + smallestFifthString + " ¢, which is the smallest fifth for which standard notation makes sense.\nThe plugin can work anyway, but it could produce some counterintuitive results.\nTune the score anyway?";
								fifthSizeDialog.open();
							}
							else if (fifthSize > largestFifth)
							{
								fifthSizeDialog.text = "The input fifth is larger than " + largestFifthString + " ¢, which is the largest fifth for which standard notation makes sense.\nThe plugin can work anyway, but it could produce some counterintuitive results.\nTune the score anyway?";
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
					}
				}
			}
		}
		
		Row
		{
			x: 10;
			y: 75;
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
						fifthSizeField.text = defaultFifth;
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
						fifthSizeField.text = justFifth - syntonicComma / 3;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "2/7 Comma";
					onClicked:
					{
						fifthSizeField.text = justFifth - syntonicComma * 2 / 7;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "7/26 Comma";
					onClicked:
					{
						fifthSizeField.text = justFifth - syntonicComma * 7 / 26;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/4 Comma";
					onClicked:
					{
						fifthSizeField.text = justFifth - syntonicComma / 4;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "2/9 Comma";
					onClicked:
					{
						fifthSizeField.text = justFifth - syntonicComma * 2 / 9;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/5 Comma";
					onClicked:
					{
						fifthSizeField.text = justFifth - syntonicComma / 5;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/6 Comma";
					onClicked:
					{
						fifthSizeField.text = justFifth - syntonicComma / 6;
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
						fifthSizeField.text = justFifth;
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
					id: addCustom;
					visible: true;
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
					id: deleteCustom;
					visible: false;
					onClicked:
					{
						try
						{
							customTuningChoices.clear();
							var fileContent = customTuningsIO.read();
							fileContent = fileContent.split("\n");
							for (var i = 0; i < fileContent.length; i++)
							{
								if (fileContent[i].trim() != "")
								{
									var rowData = parseTsvRow(fileContent[i]);
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
			y: 675;
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
	
	/**
	 * Tune the notes in the selection, or the entire score if nothing is
	 * selected, according to the selected fifth size.
	 */
	function tuneNotes()
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
									notes[j].tuning = calculateTuningOffset(notes[j]);
								}
							}
							
							var notes = cursor.element.notes;
							for (var i = 0; i < notes.length; i++)
							{
								notes[i].tuning = calculateTuningOffset(notes[i]);
							}
						}
					}
					
					cursor.next();
				}
			}
		}
		
		curScore.endCmd();
		
		quit();
	}
	
	/**
	 * Return the amount of cents necessary to tune the input note according to
	 * the input fifth size.
	 */
	function calculateTuningOffset(note)
	{
		// Get the tuning offset for the input note with respect to 12EDO, based
		// on its tonal pitch class.
		var noteLetter = "";
		switch (note.tpc1 % 7)
		{
			case 0:
				noteLetter = "C";
				break;
			
			case 2:
			case -5:
				noteLetter = "D";
				break;
			
			case 4:
			case -3:
				noteLetter = "E";
				break;
			
			case 6:
			case -1:
				noteLetter = "F";
				break;
			
			case 1:
			case -6:
				noteLetter = "G";
				break;
			
			case 3:
			case -4:
				noteLetter = "A";
				break;
			
			case 5:
			case -2:
				noteLetter = "B";
				break;
		}
		var tuningOffset = baseNotesOffset[noteLetter];
		// Add the tuning offset due to the accidental.  Each semitone adds 7
		// fifth deviations to the note's tuning, because we have to move 7
		// steps in the circle of fifths to get to the altered note.
		var tpcAccidental = Math.floor((note.tpc1 + 1) / 7) - 2;
		tuningOffset -= tpcAccidental * 7 * fifthDeviation;
		return tuningOffset;
	}
	
	Component.onCompleted:
	{
		// Initialise monospaced font.
		for (var i = 0; i < preferredFonts.length; i++)
		{
			if (Qt.fontFamilies().indexOf(preferredFonts[i]) !== -1)
			{
				monospacedFont = preferredFonts[i];
				break;
			}
		}
		
		// Initialise output message area.
		outputMessageArea.text = "-- Fifth Generated Tuner -- Version " + version + " --";
		
		try
		{
			loadCustomTunings();
		}
		catch (error)
		{
			outputMessageArea.error;
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
	 * Round the input number to one digit after the decimal point.
	 */
	function roundToOneDecimalDigit(n)
	{
		try
		{
			if (isNaN(n))
			{
				throw "The input is not numeric: " + n;
			}
			var roundedNumber = "" + (Math.round(n * 10) / 10);
			if (Number.isInteger(n))
			{
				roundedNumber += ".0";
			}
			return roundedNumber;
		}
		catch (error)
		{
			console.error(error);
			return "???";
		}
	}
	
	function loadCustomTunings()
	{
		var customTuningCounter = 0;
		var fileContent = customTuningsIO.read();
		fileContent = fileContent.split("\n");
		for (var i = 0; i < fileContent.length; i++)
		{
			if (fileContent[i].trim() != "")
			{
				var rowData = parseTsvRow(fileContent[i]);
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
				if (customTuningCounter >= 5)
				{
					break;
				}
			}
		}
		if (customTuningCounter >= 5)
		{
			addCustom.visible = false;
		}
		else
		{
			addCustom.visible = true;
		}
		if (customTuningCounter >= 1)
		{
			deleteCustom.visible = true;
		}
		else
		{
			deleteCustom.visible = false;
		}
	}
	
	function newCustomTuning(tuningName, customFifthSize)
	{
		tuningName = formatForTsv(tuningName.trim());
		customFifthSize = ("" + customFifthSize).trim();
		if ((customFifthSize == "") || isNaN(customFifthSize))
		{
			throw "Invalid custom fifth size: " + customFifthSize;
		}
		
		var fileContent = customTuningsIO.read();
		fileContent += tuningName + "\t" + customFifthSize;
		customTuningsIO.write(fileContent);
	}
	
	function parseTsvRow(s)
	{
		s = s.split("\t");
		for (var i = 0; i < s.length; i++)
		{
			s[i] = s[i].replace(/\\t/g, "\t");
			s[i] = s[i].replace(/\\\\/g, "\\");
			s[i] = s[i].replace(/\\n/g, "\n");
			s[i] = s[i].replace(/\\r/g, "\r");
		}
		return s;
	}
	
	function formatForTsv(s)
	{
		s = s.replace(/\t/g, "\\t");
		s = s.replace(/\\/g, "\\\\");
		s = s.replace(/\n/g, "\\n");
		s = s.replace(/\r/g, "\\r");
		return s;
	}
}
