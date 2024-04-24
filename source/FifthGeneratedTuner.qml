/*
	A Musescore plugin for tuning a score based on the specified fifth size
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


import QtQuick 2.0
import QtQuick.Controls 1.3
import QtQuick.Controls.Styles 1.3
import MuseScore 3.0

MuseScore
{
	title: qsTr("Fifth Generated Tuner");
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	categoryCode: "playback";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified size for the fifth.";
	version: "0.7.0";
	
	pluginType: "dialog";
	width: 520;
	height: 660;
	
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
	// cease to make sense.  It's the same fifth as 7EDO.
	property var smallestFifth: 1200.0 / 7 * 4;
	// Size in censt of the largest fifth after which the standard notation
	// cease to make sense.  It's the same fifth as 5EDO.
	property var largestFifth: 1200.0 / 5 * 3;
	// String variables containing the sizes of the smallest and largest fifths,
	// rounded to 1 digit after the decimal point.
	property var smallestFifthString: "" + (Math.round(smallestFifth * 10) / 10);
	property var largestFifthString: "" + (Math.round(largestFifth * 10) / 10);
	// Size in cents of the fifth selected by the user.
	property var fifthSize;
	// Difference in cents between a 12EDO fifth and the fifh selected by the
	// user.
	property var fifthDeviation;
	
	// Offset in cents between the notes in 12EDO and their counterpart in other
	// tuning systems.
	property variant centOffsets:
	{
		"C":
		{
			"bb": 2 * fifthDeviation + 14 * fifthDeviation,
			"b": 2 * fifthDeviation + 7 * fifthDeviation,
			"h": 2 * fifthDeviation,
			"#": 2 * fifthDeviation - 7 * fifthDeviation,
			"x": 2 * fifthDeviation - 14 * fifthDeviation
		},
		"D":
		{
			"bb": 14 * fifthDeviation,
			"b": 7 * fifthDeviation,
			"h": 0,
			"#": -7 * fifthDeviation,
			"x": -14 * fifthDeviation
		},
		"E":
		{
			"bb": -2 * fifthDeviation + 14 * fifthDeviation,
			"b": -2 * fifthDeviation + 7 * fifthDeviation,
			"h": -2 * fifthDeviation,
			"#": -2 * fifthDeviation - 7 * fifthDeviation,
			"x": -2 * fifthDeviation - 14 * fifthDeviation
		},
		"F":
		{
			"bb": 3 * fifthDeviation + 14 * fifthDeviation,
			"b": 3 * fifthDeviation + 7 * fifthDeviation,
			"h": 3 * fifthDeviation,
			"#": 3 * fifthDeviation - 7 * fifthDeviation,
			"x": 3 * fifthDeviation - 14 * fifthDeviation
		},
		"G":
		{
			"bb": 1 * fifthDeviation + 14 * fifthDeviation,
			"b": 1 * fifthDeviation + 7 * fifthDeviation,
			"h": 1 * fifthDeviation,
			"#": 1 * fifthDeviation - 7 * fifthDeviation,
			"x": 1 * fifthDeviation - 14 * fifthDeviation
		},
		"A":
		{
			"bb": -1 * fifthDeviation + 14 * fifthDeviation,
			"b": -1 * fifthDeviation + 7 * fifthDeviation,
			"h": -1 * fifthDeviation,
			"#": -1 * fifthDeviation - 7 * fifthDeviation,
			"x": -1 * fifthDeviation - 14 * fifthDeviation
		},
		"B":
		{
			"bb": -3 * fifthDeviation + 14 * fifthDeviation,
			"b": -3 * fifthDeviation + 7 * fifthDeviation,
			"h": -3 * fifthDeviation,
			"#": -3 * fifthDeviation - 7 * fifthDeviation,
			"x": -3 * fifthDeviation - 14 * fifthDeviation
		},
	}
	
	Rectangle
	{
		anchors.fill: parent;
		
		Row
		{
			x:10;
			y: 10;
			spacing: 10;
			
			Text
			{
				text: "Size of the fifth in cents:";
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
					// Only quit the plugin if a correctly formatted fifth was
					// provided as input.
					var correctlyFormattedFifth = true;
				
					try
					{
						// Read the input fifth size.
						fifthSize = parseFloat(fifthSizeField.text);
						if (isNaN(fifthSize))
						{
							correctlyFormattedFifth = false;
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
							if (fifthSize < smallestFifth)
							{
								console.log("WARNING: The input fifth is smaller than " + smallestFifthString + " ¢, which is the smallest fifth for which standard notation makes sense.");
							}
							else if (fifthSize > largestFifth)
							{
								console.log("WARNING: The input fifth is larger than " + largestFifthString + " ¢, which is the smallest fifth for which standard notation makes sense.");
							}
						
							fifthDeviation = defaultFifth - fifthSize;
							tuneNotes();
						}
					}
					catch (error)
					{
						outputMessageArea.text = error;
					}
					finally
					{
						if (correctlyFormattedFifth)
						{
							quit();
						}
					}
				}
			}
		}
		
		Row
		{
			x:10;
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
					text: "43";
					onClicked:
					{
						fifthSizeField.text = 1200.0 / 43 * 25;
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
					text: "Other";
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
			}
		}
		
		Row
		{
			x:10;
			y: 600;
			spacing: 10;
			
			TextArea
			{
				id: outputMessageArea;
				text: "";
				font.family: monospacedFont;
				readOnly: true;
				width: 500;
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
									try
									{
										notes[j].tuning = calculateTuningOffset(notes[j]);
									}
									catch (error)
									{
										console.error(error);
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
									console.error(error);
								}
							}
						}
					}
					
					cursor.next();
				}
			}
		}
		
		curScore.endCmd();
	}
	
	/**
	 * Return the amount of cents necessary to tune the input note according to
	 * the input fifth size.
	 */
	function calculateTuningOffset(note)
	{
		switch (note.tpc)
		{
			case -1:
				return centOffsets["F"]["bb"];

			case 0:
				return centOffsets["C"]["bb"];

			case 1:
				return centOffsets["G"]["bb"];

			case 2:
				return centOffsets["D"]["bb"];

			case 3:
				return centOffsets["A"]["bb"];

			case 4:
				return centOffsets["E"]["bb"];

			case 5:
				return centOffsets["B"]["bb"];

			case 6:
				return centOffsets["F"]["b"];

			case 7:
				return centOffsets["C"]["b"];

			case 8:
				return centOffsets["G"]["b"];

			case 9:
				return centOffsets["D"]["b"];

			case 10:
				return centOffsets["A"]["b"];

			case 11:
				return centOffsets["E"]["b"];

			case 12:
				return centOffsets["B"]["b"];

			case 13:
				return centOffsets["F"]["h"];

			case 14:
				return centOffsets["C"]["h"];

			case 15:
				return centOffsets["G"]["h"];

			case 16:
				return centOffsets["D"]["h"];

			case 17:
				return centOffsets["A"]["h"];

			case 18:
				return centOffsets["E"]["h"];

			case 19:
				return centOffsets["B"]["h"];

			case 20:
				return centOffsets["F"]["#"];

			case 21:
				return centOffsets["C"]["#"];

			case 22:
				return centOffsets["G"]["#"];

			case 23:
				return centOffsets["D"]["#"];

			case 24:
				return centOffsets["A"]["#"];

			case 25:
				return centOffsets["E"]["#"];

			case 26:
				return centOffsets["B"]["#"];

			case 27:
				return centOffsets["F"]["x"];

			case 28:
				return centOffsets["C"]["x"];

			case 29:
				return centOffsets["G"]["x"];

			case 30:
				return centOffsets["D"]["x"];

			case 31:
				return centOffsets["A"]["x"];

			case 32:
				return centOffsets["E"]["x"];

			case 33:
				return centOffsets["B"]["x"];
			
			default:
				throw "Could not resolve the tpc: " + note.tpc;
		}
	}
	
	Component.onCompleted:
	{
		// Format the smallest and largest fifths so that they have a digit
		// after the decimal point, even if they are integer numbers.
		if (Number.isInteger(smallestFifth))
		{
			smallestFifthString += ".0";
		}
		if (Number.isInteger(largestFifth))
		{
			largestFifthString += ".0";
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
		
		// Initialise output message area.
		outputMessageArea.text = "-- Fifth Generated Tuner -- Version " + version + " --";
	}
	
	onRun:
	{
		if (typeof curScore === "undefined")
		{
			quit();
		}
	}
}
