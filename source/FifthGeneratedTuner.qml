/*
	A Musescore plugin for tuning a score based on the specified fifth size.
	Copyright (C) 2024 - 2026 Alessandro Culatti

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

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Muse.Ui
import Muse.UiComponents as MU
import FileIO 3.0
import MuseScore 3.0
import "AccidentalUtils.js" as AccidentalUtils
import "DateUtils.js" as DateUtils
import "IterationUtils.js" as IterationUtils
import "Logger.js" as Logger
import "NoteUtils.js" as NoteUtils
import "SettingsIO.js" as SettingsIO
import "StringUtils.js" as StringUtils
import "TuningUtils.js" as TuningUtils

MuseScore
{
	title: "Fifth Generated Tuner";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	categoryCode: "playback";
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	version: "1.3.4";

	pluginType: "dialog";
	property var padding: 10;
	width: childrenRect.width + 2 * padding;
	height: childrenRect.width + 2 * padding;

	property variant settings: {};

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

	FileIO
	{
		id: loggerId;
	}

/*	Dialog
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
				width: guiColumn.implicitWidth;
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
				Logger.err(error.toString());
			}
			finally
			{
				Logger.writeLogs();
			}
		}

		onRejected:
		{
			Logger.log("Tuning canceled.");
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
				Logger.err(error.toString());
			}
			finally
			{
				Logger.writeLogs();
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
				Logger.err(error.toString());
			}
			finally
			{
				Logger.writeLogs();
			}
		}
	}*/

	FileIO
	{
		id: customTuningsId;
		source: Qt.resolvedUrl(".").toString() + "CustomTunings.tsv";
	}

	FileIO
	{
		id: settingsId;
		source: Qt.resolvedUrl(".").toString() + "Settings.tsv";
	}
	
	ColumnLayout
	{
		anchors.centerIn: parent;
		spacing: padding;
		
		Row
		{
			spacing: padding;
			
			MU.StyledGroupBox
			{
				title: "Fifth size (in cents)";

				TextArea
				{
					placeholderText: qsTr(smallestFifthString + " - " + largestFifthString);
					id: fifthSizeField;
				}
			}
		}
	}

/*	Column
	{
		id: guiColumn;
		anchors.centerIn: parent;
		spacing: padding;

		Row
		{
			spacing: padding;

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
							Logger.log("Fifth size: " + fifthSize);
							fifthDeviation = TuningUtils.STANDARD_FIFTH - fifthSize;
							Logger.log("Fifth deviation: " + fifthDeviation);

							if (fifthSize < TuningUtils.SMALLEST_DIATONIC_FIFTH)
							{
								Logger.warning("Fifth smaller than the smallest diatonic fifth: " + fifthSize);
								fifthSizeDialogText.text = "The input fifth is smaller than " + smallestFifthString
										+ " ¢, which is the smallest fifth for which standard notation makes sense."
										+ "\nThe plugin can work anyway, but it could produce some counterintuitive "
										+ "results.\nTune the score anyway?";
								fifthSizeDialog.open();
							}
							else if (fifthSize > TuningUtils.LARGEST_DIATONIC_FIFTH)
							{
								Logger.warning("Fifth larger than the largest diatonic fifth: " + fifthSize);
								fifthSizeDialogText.text = "The input fifth is larger than " + largestFifthString
										+ " ¢, which is the largest fifth for which standard notation makes sense."
										+ "\nThe plugin can work anyway, but it could produce some counterintuitive "
										+ "results.\nTune the score anyway?";
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
						Logger.err(error);
					}
					finally
					{
						Logger.writeLogs();
					}
				}
			}
		}

		Row
		{
			spacing: padding;

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
						Logger.log("Reference note changed to: " + referenceNote);
					}
					catch (error)
					{
						outputMessageArea.text = error.toString();
						Logger.err(error);
					}
					finally
					{
						Logger.writeLogs();
					}
				}
			}

			ComboBox
			{
				id: referenceNoteAccidentalComboBox;
				model: [
					AccidentalUtils.UNICODE_ACCIDENTALS["FLAT3"],
					AccidentalUtils.UNICODE_ACCIDENTALS["FLAT2"],
					AccidentalUtils.UNICODE_ACCIDENTALS["FLAT"],
					AccidentalUtils.UNICODE_ACCIDENTALS["NATURAL"],
					AccidentalUtils.UNICODE_ACCIDENTALS["SHARP"],
					AccidentalUtils.UNICODE_ACCIDENTALS["SHARP2"],
					AccidentalUtils.UNICODE_ACCIDENTALS["SHARP3"]
				];
				width: 50;
				font: ui.theme.musicalFont;

				delegate: ItemDelegate
				{
					text: modelData;
					font: ui.theme.musicalFont;
					height: 30;
				}

				onActivated:
				{
					try
					{
						settings["ReferenceNoteAccidentalIndex"] = referenceNoteAccidentalComboBox.currentIndex;
						writeSettings();
						referenceNoteAccidental = referenceNoteAccidentalComboBox.currentText;
						referenceNoteAccidental = AccidentalUtils.UNICODE_TO_ASCII[referenceNoteAccidental];
						referenceNoteAccidental = referenceNoteAccidental.replace(
								AccidentalUtils.UNICODE_TO_ASCII[AccidentalUtils.UNICODE_ACCIDENTALS["NATURAL"]], ""
						);
						referenceNote = referenceNoteName + referenceNoteAccidental;
						Logger.log("Reference note changed to: " + referenceNote);
					}
					catch (error)
					{
						outputMessageArea.text = error.toString();
						Logger.err(error);
					}
					finally
					{
						Logger.writeLogs();
					}
				}
			}
		}

		Row
		{
			anchors.horizontalCenter: parent.horizontalCenter;
			spacing: 5 * padding;

			Column
			{
				spacing: padding;

				Text
				{
					text: "EDOs";
					font.pixelSize: 15;
					anchors.horizontalCenter: parent.horizontalCenter;
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
						fifthSizeField.text = TuningUtils.STANDARD_FIFTH;
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
				spacing: padding;

				Text
				{
					text: "Meantones";
					font.pixelSize: 15;
					anchors.horizontalCenter: parent.horizontalCenter;
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
				spacing: padding;

				Text
				{
					text: "Others";
					font.pixelSize: 15;
					anchors.horizontalCenter: parent.horizontalCenter;
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

				Text
				{
					text: "Customs";
					font.pixelSize: 15;
					// In order to keep the buttons aligned to each other.
					height: buttonHeight;
					anchors.horizontalCenter: parent.horizontalCenter;
					verticalAlignment: Text.AlignBottom;
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
			anchors.horizontalCenter: parent.horizontalCenter;
			spacing: padding;

			TextArea
			{
				id: outputMessageArea;
				text: "";
				font.family: monospacedFont;
				readOnly: true;
				wrapMode: TextEdit.Wrap;
				width: 400;
				height: 50;
			}
		}
	}*/

	/**
	 * Tune the notes in the selection, or the entire score if nothing is
	 * selected, according to the selected fifth size.
	 */
	function tuneNotes()
	{
		try
		{
			Logger.log("Tuning notes.");

			IterationUtils.iterate(
				curScore,
				{
					"onNote": onNote
				},
				Logger
			);

			Logger.log("Notes tuned: " + tunedNotes + " / " + totalNotes);
		}
		catch (error)
		{
			Logger.fatal(error);
		}
		finally
		{
			Logger.writeLogs();
			quit();
		}
	}

	function onNote(note)
	{
		totalNotes += 1;

		try
		{
			Logger.trace(
					"Tuning note: " + NoteUtils.getNoteLetter(note) + " " + AccidentalUtils.getAccidentalName(note)
					+ " " + NoteUtils.getOctave(note)
			);
			var tuningOffset = -TuningUtils.circleOfFifthsDistance(note, referenceNote) * fifthDeviation;
			Logger.trace("Tuning offset: " + tuningOffset);
			note.tuning = tuningOffset;
			tunedNotes += 1;
		}
		catch (error)
		{
			Logger.err(error);
		}
	}

	Component.onCompleted:
	{
		try
		{
			settings = SettingsIO.readTsvFile(settingsId);

			Logger.initialise(loggerId, parseInt(settings["LogLevel"]));
			Logger.log("-- Fifth Generated Tuner -- Version " + version + " --");

			// Initialise reference note.
			referenceNoteNameComboBox.currentIndex = settings["ReferenceNoteNameIndex"];
			referenceNoteName = referenceNoteNameComboBox.currentText;
			referenceNoteAccidentalComboBox.currentIndex = settings["ReferenceNoteAccidentalIndex"];
			referenceNoteAccidental = referenceNoteAccidentalComboBox.currentText;
			referenceNoteAccidental = AccidentalUtils.UNICODE_TO_ASCII[referenceNoteAccidental];
			referenceNoteAccidental = referenceNoteAccidental.replace(
					AccidentalUtils.UNICODE_TO_ASCII[AccidentalUtils.UNICODE_ACCIDENTALS["NATURAL"]], ""
			);
			referenceNote = referenceNoteName + referenceNoteAccidental;
			Logger.log("Reference note set to: " + referenceNote);

			// Initialise custom tunings buttons.
//			loadCustomTunings();
		}
		catch (error)
		{
			Logger.fatal(error.toString());
		}
		finally
		{
			Logger.writeLogs();
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
		Logger.log("Updating settings file.");
		SettingsIO.writeTsvFile(settings, settingsId);
		Logger.log("Settings file updated successfully.");
		Logger.writeLogs();
	}

	/**
	 * Load the custom tunings from the cunfiguration file, and set the
	 * properties of the custom tunings buttons.
	 */
	function loadCustomTunings()
	{
		Logger.log("Loading custom tunings.");

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
		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		for (var tuningName in fileContent)
		{
			var fifthSize = fileContent[tuningName];
			Logger.trace("Name: " + tuningName + "; Fifth Size: " + fifthSize);
			switch (customTuningCounter)
			{
				case 0:
					custom0.text = tuningName;
					custom0.customFifthSize0 = fifthSize;
					custom0.visible = true;
					deleteCustomCheckbox0.text = tuningName;
					deleteCustomCheckbox0.visible = true;
					break;

				case 1:
					custom1.text = tuningName;
					custom1.customFifthSize1 = fifthSize;
					custom1.visible = true;
					deleteCustomCheckbox1.text = tuningName;
					deleteCustomCheckbox1.visible = true;
					break;

				case 2:
					custom2.text = tuningName;
					custom2.customFifthSize2 = fifthSize;
					custom2.visible = true;
					deleteCustomCheckbox2.text = tuningName;
					deleteCustomCheckbox2.visible = true;
					break;

				case 3:
					custom3.text = tuningName;
					custom3.customFifthSize3 = fifthSize;
					custom3.visible = true;
					deleteCustomCheckbox3.text = tuningName;
					deleteCustomCheckbox3.visible = true;
					break;

				case 4:
					custom4.text = tuningName;
					custom4.customFifthSize4 = fifthSize;
					custom4.visible = true;
					deleteCustomCheckbox4.text = tuningName;
					deleteCustomCheckbox4.visible = true;
					break;
			}

			customTuningCounter++;
			if (customTuningCounter >= maxCustomTunings)
			{
				break;
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

		Logger.log("Custom tunings loaded successfully.");
		Logger.writeLogs();
	}

	/**
	 * Add the input custom tuning to the configuration file.
	 */
	function newCustomTuning(tuningName, customFifthSize)
	{
		tuningName = tuningName.trim();
		customFifthSize = ("" + customFifthSize).trim();
		Logger.log("New custom tuning name: " + tuningName + "; Fifth size: " + customFifthSize);
		if ((customFifthSize == "") || isNaN(customFifthSize))
		{
			throw "Invalid custom fifth size: " + customFifthSize;
		}

		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		if (fileContent.hasOwnProperty(tuningName))
		{
			throw "Tuning name already present: " + tuningName;
		}
		fileContent[tuningName] = customFifthSize;
		SettingsIO.writeTsvFile(fileContent, customTuningsId);

		Logger.log("New custom tuning added successfully.");
		Logger.writeLogs();
	}

	/**
	 * Delete the tunings with the input names from the configuration file.
	 */
	function deleteCustomTunings(tuningsToDelete)
	{
		Logger.log("Deleting custom tunings: " + tuningsToDelete.join(", "));
		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		for (var tuningName of tuningsToDelete)
		{
			Logger.trace("Deleting key: " + tuningName);
			delete fileContent[tuningName];
		}
		SettingsIO.writeTsvFile(fileContent, customTuningsId);

		Logger.log("Tuning deleted successfully.");
		Logger.writeLogs();
	}
}
