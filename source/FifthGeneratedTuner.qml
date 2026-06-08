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
import FileIO
import Muse.Ui
import Muse.UiComponents
import MuseScore
import "AccidentalUtils.js" as AccidentalUtils
import "IterationUtils.js" as IterationUtils
import "Logger.js" as Logger
import "NoteUtils.js" as NoteUtils
import "SettingsIO.js" as SettingsIO
import "TuningUtils.js" as TuningUtils

MuseScore
{
	title: "Fifth Generated Tuner";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	categoryCode: "playback";
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	version: "1.4.0";
	pluginType: "dialog";

	property variant settings: {};

	id: root;
	readonly property int defaultPadding: 10;
	width: childrenRect.width + 2 * defaultPadding;
	height: childrenRect.height + 2 * defaultPadding;

	// Difference in cents between a 12EDO fifth and the fifth selected by the
	// user.
	property var fifthDeviation;

	// Reference note, which has a tuning offset of zero.
	property var referenceNote;

	// Amount of notes which were tuned successfully.
	property var tunedNotes;
	// Total amount of notes encountered in the portion of the score to tune.
	property var totalNotes;

	property var customTuningsButtons: [
		custom0,
		custom1,
		custom2,
		custom3,
		custom4
	];

	property var deleteCustomTuningsCheckBoxes: [
		deleteCustomCheckBox0,
		deleteCustomCheckBox1,
		deleteCustomCheckBox2,
		deleteCustomCheckBox3,
		deleteCustomCheckBox4
	];

	FileIO
	{
		id: settingsId;
		source: Qt.resolvedUrl(".").toString() + "Settings.tsv";
	}

	FileIO
	{
		id: customTuningsId;
		source: Qt.resolvedUrl(".").toString() + "CustomTunings.tsv";
	}

	FileIO
	{
		id: loggerId;
	}

	StyledDialogView
	{
		id: fifthSizeDialog;
		title: "Warning: Fifth Size";
		contentWidth: fifthSizeWarningColumn.width + 2 * defaultPadding;
		contentHeight: fifthSizeWarningColumn.height + 2 * defaultPadding;

		ColumnLayout
		{
			id: fifthSizeWarningColumn;
			spacing: defaultPadding;
			anchors.centerIn: parent;

			StyledTextLabel
			{
				id: fifthSizeDialogText;
				Layout.maximumWidth: 500;
				wrapMode: Text.WordWrap;
				horizontalAlignment: Text.AlignLeft;
				text: "The input fifth size is outside the diatonic range ("
					+ TuningUtils.SMALLEST_DIATONIC_FIFTH.toFixed(1) + " c - "
					+ TuningUtils.LARGEST_DIATONIC_FIFTH.toFixed(1) + " c). Standard music notation ceases to work "
					+ "properly for fifths outside of this range.\n"
					+ "The plugin can tune the score, but this could produce counterintuitive results.\n"
					+ "Do you want to tune the score anyway?";
			}

			RowLayout
			{
				spacing: defaultPadding;
				Layout.alignment: Qt.AlignRight;

				FlatButton
				{
					text: "Tune";

					onClicked:
					{
						try
						{
							tuneNotes();
							fifthSizeDialog.close();
						}
						catch (error)
						{
							displayErrorMessage(error);
						}
					}
				}

				FlatButton
				{
					text: "Cancel";

					onClicked:
					{
						Logger.log("Tuning canceled by the user.");
						Logger.writeLogs();
						fifthSizeDialog.close();
					}
				}
			}
		}
	}

	StyledDialogView
	{
		id: newCustomTuningDialog;
		title: "New Custom Tuning";
		contentWidth: newCustomTuningColumn.width + 2 * defaultPadding;
		contentHeight: newCustomTuningColumn.height + 2 * defaultPadding;

		ColumnLayout
		{
			id: newCustomTuningColumn;
			spacing: defaultPadding;
			anchors.centerIn: parent;

			RowLayout
			{
				spacing: defaultPadding;

				StyledGroupBox
				{
					title: "Tuning Name";
					width: customTuningNameField.width + 2 * defaultPadding;

					TextInputField
					{
						id: customTuningNameField;
						width: tuneButton.width;
					}
				}

				StyledGroupBox
				{
					title: "Fifth Size";
					width: customTuningFifthSizeField.width + 2 * defaultPadding;

					TextInputField
					{
						id: customTuningFifthSizeField;
						width: tuneButton.width;
					}
				}
			}

			RowLayout
			{
				spacing: defaultPadding;
				Layout.alignment: Qt.AlignRight;

				FlatButton
				{
					text: "Add";

					onClicked:
					{
						try
						{
							newCustomTuning(
								customTuningNameField.inputField.text, customTuningFifthSizeField.inputField.text
							);
							loadCustomTunings();
							newCustomTuningDialog.close();
						}
						catch (error)
						{
							displayErrorMessage(error);
						}
					}
				}

				FlatButton
				{
					text: "Cancel";

					onClicked:
					{
						newCustomTuningDialog.close();
					}
				}
			}
		}
	}

	StyledDialogView
	{
		id: deleteCustomTuningDialog;
		title: "Delete Custom Tunings";
		contentWidth: deleteCustomTuningColumn.width + 2 * defaultPadding;
		contentHeight: deleteCustomTuningColumn.height + 2 * defaultPadding;

		ColumnLayout
		{
			id: deleteCustomTuningColumn;
			spacing: defaultPadding;
			anchors.centerIn: parent;

			CheckBox
			{
				id: deleteCustomCheckBox0;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox0.checked = !deleteCustomCheckBox0.checked;
				}
			}

			CheckBox
			{
				id: deleteCustomCheckBox1;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox1.checked = !deleteCustomCheckBox1.checked;
				}
			}

			CheckBox
			{
				id: deleteCustomCheckBox2;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox2.checked = !deleteCustomCheckBox2.checked;
				}
			}

			CheckBox
			{
				id: deleteCustomCheckBox3;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox3.checked = !deleteCustomCheckBox3.checked;
				}
			}

			CheckBox
			{
				id: deleteCustomCheckBox4;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox4.checked = !deleteCustomCheckBox4.checked;
				}
			}

			RowLayout
			{
				spacing: defaultPadding;
				Layout.alignment: Qt.AlignRight;

				FlatButton
				{
					text: "Delete";

					onClicked:
					{
						try
						{
							var customTuningsToDelete = [];
							for (var customTuningCheckBox of deleteCustomTuningsCheckBoxes)
							{
								if (customTuningCheckBox.checked)
								{
									customTuningsToDelete.push(customTuningCheckBox.text);
								}
							}
							deleteCustomTunings(customTuningsToDelete);
							loadCustomTunings();
							deleteCustomTuningDialog.close();
						}
						catch (error)
						{
							displayErrorMessage(error);
						}
					}
				}

				FlatButton
				{
					text: "Cancel";

					onClicked:
					{
						deleteCustomTuningDialog.close();
					}
				}
			}
		}
	}

	Timer
	{
		id: errorDialogTimer;
		interval: 0;
		repeat: false;

		onTriggered:
		{
			errorDialog.open();
		}
	}

	StyledDialogView
	{
		id: errorDialog;
		title: "Error";
		contentWidth: errorColumn.width + 2 * defaultPadding;
		contentHeight: errorColumn.height + 2 * defaultPadding;

		ColumnLayout
		{
			id: errorColumn;
			spacing: defaultPadding;
			anchors.centerIn: parent;

			StyledTextLabel
			{
				id: errorDialogText;
				Layout.maximumWidth: 500;
				wrapMode: Text.WordWrap;
				horizontalAlignment: Text.AlignLeft;
				text: "";
			}

			RowLayout
			{
				spacing: defaultPadding;
				Layout.alignment: Qt.AlignRight;

				FlatButton
				{
					text: "Ok";

					onClicked:
					{
						errorDialog.close();
					}
				}
			}
		}
	}

	ColumnLayout
	{
		anchors.centerIn: parent;
		spacing: defaultPadding;

		RowLayout
		{
			spacing: defaultPadding;
			Layout.alignment: Qt.AlignHCenter;

			StyledGroupBox
			{
				title: "Fifth Size (in cents)";
				width: fifthSizeInput.width + 2 * defaultPadding;
				Layout.alignment: Qt.AlignVCenter

				ColumnLayout
				{
					spacing: defaultPadding;

					TextInputField
					{
						id: fifthSizeInput;
						width: tuneButton.width;
					}
				}
			}

			StyledGroupBox
			{
				title: "Reference Note";
				width: referenceNoteNameId.width + referenceNoteAccidentalId.width + 3 * defaultPadding;
				Layout.alignment: Qt.AlignVCenter

				RowLayout
				{
					spacing: defaultPadding;

					StyledDropdown
					{
						id: referenceNoteNameId;
						width: 80;
						model: ["A", "B", "C", "D", "E", "F", "G"];

						onActivated: function(index, value)
						{
							try
							{
								referenceNoteNameId.currentIndex = index;
								setReferenceNote();
							}
							catch (error)
							{
								displayErrorMessage(error);
							}
						}
					}

					StyledDropdown
					{
						id: referenceNoteAccidentalId;
						width: 80;
						model: [
							AccidentalUtils.UNICODE_ACCIDENTALS["FLAT2"],
							AccidentalUtils.UNICODE_ACCIDENTALS["FLAT"],
							AccidentalUtils.UNICODE_ACCIDENTALS["NATURAL"],
							AccidentalUtils.UNICODE_ACCIDENTALS["SHARP"],
							AccidentalUtils.UNICODE_ACCIDENTALS["SHARP2"]
						];

						onActivated: function(index, value)
						{
							try
							{
								referenceNoteAccidentalId.currentIndex = index;
								setReferenceNote();
							}
							catch (error)
							{
								displayErrorMessage(error);
							}
						}
					}
				}
			}

			Item
			{
				Layout.fillWidth: true;
			}

			FlatButton
			{
				text: "Tune";
				accentButton: true;
				id: tuneButton;

				onClicked:
				{
					try
					{
						var fifthSize = parseFloat(fifthSizeInput.inputField.text);
						if (isNaN(fifthSize))
						{
							if (fifthSizeInput.inputField.text)
							{
								throw "Cannot convert to number the input fifth size: "
									+ fifthSizeInput.inputField.text;
							}
							else
							{
								throw "Empty fifth size field.";
							}
						}
						else
						{
							fifthDeviation = fifthSize - TuningUtils.STANDARD_FIFTH;
							Logger.log("Fifth size: " + fifthSize + "; Fifth deviation: " + fifthDeviation);
							if (
								(fifthSize < TuningUtils.SMALLEST_DIATONIC_FIFTH)
								|| (fifthSize > TuningUtils.LARGEST_DIATONIC_FIFTH)
							) {
								Logger.warning("Fifth outside the diatonic range.");
								fifthSizeDialog.open();
							}
							else
							{
								tuneNotes();
							}
						}
						Logger.writeLogs();
					}
					catch (error)
					{
						displayErrorMessage(error);
					}
				}
			}
		}

		RowLayout
		{
			spacing: defaultPadding;
			Layout.alignment: Qt.AlignHCenter;

			StyledGroupBox
			{
				title: "EDOs";
				Layout.alignment: Qt.AlignTop;

				ColumnLayout
				{
					spacing: defaultPadding;
					Layout.alignment: Qt.AlignTop;

					FlatButton
					{
						text: "5";

						onClicked:
						{
							setFifthSize(1200.0 / 5 * 3);
						}
					}

					FlatButton
					{
						text: "7";

						onClicked:
						{
							setFifthSize(1200.0 / 7 * 4);
						}
					}

					FlatButton
					{
						text: "12";

						onClicked:
						{
							setFifthSize(TuningUtils.STANDARD_FIFTH);
						}
					}

					FlatButton
					{
						text: "17";

						onClicked:
						{
							setFifthSize(1200.0 / 17 * 10);
						}
					}

					FlatButton
					{
						text: "19";

						onClicked:
						{
							setFifthSize(1200.0 / 19 * 11);
						}
					}

					FlatButton
					{
						text: "26";

						onClicked:
						{
							setFifthSize(1200.0 / 26 * 15);
						}
					}

					FlatButton
					{
						text: "29";

						onClicked:
						{
							setFifthSize(1200.0 / 29 * 17);
						}
					}

					FlatButton
					{
						text: "31";

						onClicked:
						{
							setFifthSize(1200.0 / 31 * 18);
						}
					}

					FlatButton
					{
						text: "41";

						onClicked:
						{
							setFifthSize(1200.0 / 41 * 24);
						}
					}

					FlatButton
					{
						text: "43";

						onClicked:
						{
							setFifthSize(1200.0 / 43 * 25);
						}
					}

					FlatButton
					{
						text: "50";

						onClicked:
						{
							setFifthSize(1200.0 / 50 * 29);
						}
					}
				}
			}

			StyledGroupBox
			{
				title: "Meantones";
				Layout.alignment: Qt.AlignTop;

				ColumnLayout
				{
					spacing: defaultPadding;
					Layout.alignment: Qt.AlignTop;

					FlatButton
					{
						text: "1/3 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 3);
						}
					}

					FlatButton
					{
						text: "2/7 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 2 / 7);
						}
					}

					FlatButton
					{
						text: "7/26 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 7 / 26);
						}
					}

					FlatButton
					{
						text: "1/4 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 4);
						}
					}

					FlatButton
					{
						text: "2/9 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 2 / 9);
						}
					}

					FlatButton
					{
						text: "1/5 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 5);
						}
					}

					FlatButton
					{
						text: "1/6 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 6);
						}
					}

					FlatButton
					{
						text: "Golden";

						onClicked:
						{
							setFifthSize(600.0 / 11 * (15 - Math.sqrt(5)));
						}
					}

					FlatButton
					{
						text: "Tungsten";

						onClicked:
						{
							setFifthSize(600.0 * (Math.sqrt(10) - 2));
						}
					}
				}
			}

			ColumnLayout
			{
				spacing: defaultPadding;
				Layout.alignment: Qt.AlignTop;

				StyledGroupBox
				{
					title: "Schismic Temperaments";
					Layout.alignment: Qt.AlignTop;

					ColumnLayout
					{
						spacing: defaultPadding;
						Layout.alignment: Qt.AlignTop;

						FlatButton
						{
							text: "1/8 Schisma";

							onClicked:
							{
								setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SCHISMA / 8);
							}
						}

						FlatButton
						{
							text: "2/17 Schisma";

							onClicked:
							{
								setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SCHISMA * 2 / 17);
							}
						}

						FlatButton
						{
							text: "1/9 Schisma";

							onClicked:
							{
								setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SCHISMA / 9);
							}
						}
					}
				}

				StyledGroupBox
				{
					title: "Other Tunings";
					Layout.alignment: Qt.AlignTop;

					ColumnLayout
					{
						spacing: defaultPadding;
						Layout.alignment: Qt.AlignTop;

						FlatButton
						{
							text: "Pythagorean";

							onClicked:
							{
								setFifthSize(TuningUtils.JUST_FIFTH);
							}
						}
					}
				}
			}

			StyledGroupBox
			{
				title: "Custom Tunings";
				Layout.alignment: Qt.AlignTop;

				ColumnLayout
				{
					spacing: defaultPadding;
					Layout.alignment: Qt.AlignTop;

					FlatButton
					{
						id: custom0;
						text: "";
						property var fifthSize;
						visible: false;

						onClicked:
						{
							setFifthSize(custom0.fifthSize);
						}
					}

					FlatButton
					{
						id: custom1;
						text: "";
						property var fifthSize;
						visible: false;

						onClicked:
						{
							setFifthSize(custom1.fifthSize);
						}
					}

					FlatButton
					{
						id: custom2;
						text: "";
						property var fifthSize;
						visible: false;

						onClicked:
						{
							setFifthSize(custom2.fifthSize);
						}
					}

					FlatButton
					{
						id: custom3;
						text: "";
						property var fifthSize;
						visible: false;

						onClicked:
						{
							setFifthSize(custom3.fifthSize);
						}
					}

					FlatButton
					{
						id: custom4;
						text: "";
						property var fifthSize;
						visible: false;

						onClicked:
						{
							setFifthSize(custom4.fifthSize);
						}
					}

					FlatButton
					{
						id: addCustom;
						text: "Add Custom";

						onClicked:
						{
							newCustomTuningDialog.open();
						}
					}

					FlatButton
					{
						id: deleteCustom;
						text: "Delete Custom";

						onClicked:
						{
							for (var customTuningCheckBox of deleteCustomTuningsCheckBoxes)
							{
								customTuningCheckBox.checked = false;
							}
							deleteCustomTuningDialog.open();
						}
					}
				}
			}
		}
	}

	Component.onCompleted:
	{
		try
		{
			settings = SettingsIO.readTsvFile(settingsId);

			Logger.initialise(loggerId, parseInt(settings["LogLevel"]));
			Logger.log(title + " - v" + version);

			referenceNoteNameId.currentIndex = settings["ReferenceNoteNameIndex"];
			referenceNoteAccidentalId.currentIndex = settings["ReferenceNoteAccidentalIndex"];
			referenceNote = getAsciiReferenceNote();
			Logger.log("Reference note set to: " + referenceNote);

			loadCustomTunings();
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
	 * Tune the notes in the selection, or the entire score if nothing is
	 * selected, according to the selected fifth size.
	 */
	function tuneNotes()
	{
		try
		{
			Logger.log("Tuning notes.");
			tunedNotes = 0;
			totalNotes = 0;
			IterationUtils.iterate(
				curScore,
				{
					"onNote": onNote
				},
				Logger
			);
			Logger.log("Notes tuned: " + tunedNotes + " / " + totalNotes);
			Logger.writeLogs();
			quit();
		}
		catch (error)
		{
			displayErrorMessage(error);
		}
	}

	function onNote(note)
	{
		totalNotes++;

		try
		{
			Logger.trace(
				"Tuning note: " + NoteUtils.getNoteLetter(note) + " " + AccidentalUtils.getAccidentalName(note) + " "
				+ NoteUtils.getOctave(note)
			);
			var tuningOffset = TuningUtils.circleOfFifthsDistance(note, referenceNote) * fifthDeviation;
			Logger.trace("Tuning offset: " + tuningOffset);
			note.tuning = tuningOffset;
			tunedNotes++;
		}
		catch (error)
		{
			displayErrorMessage(error);
		}
	}

	/**
	 * Load the custom tunings from the configuration file, and set the
	 * properties of the custom tunings buttons.
	 */
	function loadCustomTunings()
	{
		Logger.log("Loading custom tunings.");

		for (var customButton of customTuningsButtons)
		{
			customButton.visible = false;
		}
		for (var customTuningCheckBox of deleteCustomTuningsCheckBoxes)
		{
			customTuningCheckBox.visible = false;
		}

		var counter = 0;
		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		for (var tuningName in fileContent)
		{
			var fifthSize = fileContent[tuningName];
			Logger.trace("Name: " + tuningName + "; Fifth Size: " + fifthSize);
			if (counter >= customTuningsButtons.length)
			{
				Logger.warning("Too many custom tunings.");
				continue;
			}

			customTuningsButtons[counter].text = tuningName;
			customTuningsButtons[counter].fifthSize = fifthSize;
			customTuningsButtons[counter].visible = true;
			deleteCustomTuningsCheckBoxes[counter].text = tuningName;
			deleteCustomTuningsCheckBoxes[counter].visible = true;

			counter++;
		}

		if (counter < customTuningsButtons.length)
		{
			addCustom.enabled = true;
		}
		else
		{
			addCustom.enabled = false;
		}

		if (counter > 0)
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
	function newCustomTuning(tuningName, fifthSize)
	{
		tuningName = tuningName.trim();
		if (!tuningName)
		{
			throw "Empty custom tuning name.";
		}
		fifthSize = ("" + fifthSize).trim();
		if (!fifthSize)
		{
			throw "Empty fifth size.";
		}
		else if (isNaN(fifthSize))
		{
			throw "Invalid custom fifth size: " + fifthSize;
		}
		Logger.log("New custom tuning name: " + tuningName + "; Fifth size: " + fifthSize);

		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		if (fileContent.hasOwnProperty(tuningName))
		{
			throw "Custom tuning name already present: " + tuningName;
		}
		fileContent[tuningName] = fifthSize;
		SettingsIO.writeTsvFile(fileContent, customTuningsId, "TUNING_NAME", "FIFTH_SIZE");

		Logger.log("New custom tuning added successfully.");
		Logger.writeLogs();
	}

	/**
	 * Delete the tunings with the specified input names from the configuration
	 * file.
	 */
	function deleteCustomTunings(tuningsToDelete)
	{
		Logger.log("Deleting custom tunings: " + tuningsToDelete.join(", "));
		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		for (var tuningName of tuningsToDelete)
		{
			Logger.trace("Deleting tuning: " + tuningName);
			delete fileContent[tuningName];
		}
		SettingsIO.writeTsvFile(fileContent, customTuningsId, "TUNING_NAME", "FIFTH_SIZE");
		Logger.log("Custom tunings deleted successfully.");
		Logger.writeLogs();
	}

	/**
	 * Set the fifth size text box to the specified value.
	 */
	function setFifthSize(fifthSize)
	{
		fifthSizeInput.inputField.text = fifthSize;
		Logger.log("Fifth size set to: " + fifthSize);
		Logger.writeLogs();
	}

	/**
	 * Read the values selected in the reference note combo boxes, and save them
	 * to the configuration file.
	 */
	function setReferenceNote()
	{
		settings["ReferenceNoteNameIndex"] = referenceNoteNameId.currentIndex;
		settings["ReferenceNoteAccidentalIndex"] = referenceNoteAccidentalId.currentIndex;
		SettingsIO.writeTsvFile(settings, settingsId);

		referenceNote = getAsciiReferenceNote();
		Logger.log("Reference note changed to: " + referenceNote);
		Logger.writeLogs();
	}

	/**
	 * Read the values selected in the reference note combo boxes, and return an
	 * ASCII letter only representation of the selected note.
	 */
	function getAsciiReferenceNote()
	{
		var asciiReferenceNote = referenceNoteNameId.currentText;
		asciiReferenceNote += AccidentalUtils.UNICODE_TO_ASCII[referenceNoteAccidentalId.currentText];
		return asciiReferenceNote.replace(
			AccidentalUtils.UNICODE_TO_ASCII[AccidentalUtils.UNICODE_ACCIDENTALS["NATURAL"]], ""
		);
	}

	/**
	 * Log the input error message, and display it to the user using a Dialog.
	 */
	function displayErrorMessage(e)
	{
		Logger.err(e.toString());
		Logger.writeLogs();

		errorDialogText.text = e.toString();
		errorDialogTimer.start();
	}
}
