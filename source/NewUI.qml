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
import Muse.UiComponents as MU
import MuseScore 3.0
import "Logger.js" as Logger
import "SettingsIO.js" as SettingsIO
import "TuningUtils.js" as TuningUtils

MuseScore
{
	title: "Fifth Generated Tuner";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	categoryCode: "playback";
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	version: "1.3.4";
	pluginType: "dialog";

	property variant settings: {};

	readonly property int defaultPadding: 10;

	id: root;
	width: childrenRect.width + 2 * defaultPadding;
	height: childrenRect.height + 2 * defaultPadding;

	// Difference in cents between a 12EDO fifth and the fifth selected by the
	// user.
	property var fifthDeviation;

	// Reference note, which has a tuning offset of zero.
	property var referenceNote;

	// Total amount of notes encountered in the portion of the score to tune.
	property var totalNotes;
	// Amount of notes which were tuned successfully.
	property var tunedNotes;

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
		id: logggerId;
	}

	Dialog
	{
		id: fifthSizeDialog;
		title: "Warning: Fifth Size";
		standardButtons: Dialog.Yes | Dialog.No;

		contentItem: MU.StyledTextLabel
		{
			id: fifthSizeDialogText;
			wrapMode: Text.WordWrap;
			text: "";
		}

		onAccepted:
		{
			try
			{
				tuneNotes();
			}
			catch (error)
			{
				displayErrorMessage(error);
			}
		}

		onRejected:
		{
			Logger.log("Tuning canceled by the user.");
			Logger.writeLogs();
		}
	}

	Dialog
	{
		id: newCustomTuningDialog;
		title: "New Custom Tuning";
		standardButtons: Dialog.Ok | Dialog.Cancel;

		contentItem: ColumnLayout
		{
			spacing: defaultPadding;

			MU.StyledGroupBox
			{
				title: "Tuning Name";

				TextField
				{
					id: customTuningNameField;
				}
			}

			MU.StyledGroupBox
			{
				title: "Fifth Size";

				TextField
				{
					id: customTuningFifthSizeField;
				}
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
				displayErrorMessage(error);
			}
		}
	}

	Dialog
	{
		id: deleteCustomTuningDialog;
		title: "Delete Custom Tunings";
		standardButtons: Dialog.Ok | Dialog.Cancel;

		contentItem: ColumnLayout
		{
			spacing: defaultPadding;

			MU.CheckBox
			{
				id: deleteCustomCheckBox0;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox0.checked = !deleteCustomCheckBox0.checked;
				}
			}

			MU.CheckBox
			{
				id: deleteCustomCheckBox1;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox1.checked = !deleteCustomCheckBox1.checked;
				}
			}

			MU.CheckBox
			{
				id: deleteCustomCheckBox2;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox2.checked = !deleteCustomCheckBox2.checked;
				}
			}

			MU.CheckBox
			{
				id: deleteCustomCheckBox3;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox3.checked = !deleteCustomCheckBox3.checked;
				}
			}

			MU.CheckBox
			{
				id: deleteCustomCheckBox4;
				text: "";
				visible: false;

				onClicked:
				{
					deleteCustomCheckBox4.checked = !deleteCustomCheckBox4.checked;
				}
			}
		}

		onAccepted:
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
			}
			catch (error)
			{
				displayErrorMessage(error);
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

	Dialog
	{
		id: errorDialog;
		title: "Error";
		standardButtons: Dialog.Ok;

		contentItem: MU.StyledTextLabel
		{
			id: errorDialogText;
			wrapMode: Text.WordWrap;
			text: "";
		}
	}

	ColumnLayout
	{
		anchors.centerIn: parent;
		spacing: defaultPadding;

		RowLayout
		{
			spacing: defaultPadding;

			MU.StyledGroupBox
			{
				title: "Fifth Size (in cents)";
				width: fifthSizeInput.width + 2 * defaultPadding;
				Layout.alignment: Qt.AlignVCenter

				ColumnLayout
				{
					spacing: defaultPadding;

					TextField
					{
						placeholderText: TuningUtils.SMALLEST_DIATONIC_FIFTH.toFixed(1) + " - "
							+ TuningUtils.LARGEST_DIATONIC_FIFTH.toFixed(1);
						id: fifthSizeInput;
						width: 300;
					}
				}
			}

			MU.StyledGroupBox
			{
				title: "Reference Note";
				width: referenceNoteNameId.width + referenceNoteAccidentalId.width + 3 * defaultPadding;
				Layout.alignment: Qt.AlignVCenter

				RowLayout
				{
					spacing: defaultPadding;

					MU.StyledDropdown
					{
						id: referenceNoteNameId;
						width: 80;
						model: ["A", "B", "C", "D", "E", "F", "G"];
						currentIndex: 0;

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

					MU.StyledDropdown
					{
						id: referenceNoteAccidentalId;
						width: 80;
						model: ["bbb", "bb", "b", "-", "#", "x", "#x"];
						currentIndex: 3;

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

			MU.FlatButton
			{
				text: "Tune";
				accentButton: true;

				onClicked:
				{
					try
					{
						var fifthSize = parseFloat(fifthSizeInput.text);
						if (isNaN(fifthSize))
						{
							if (fifthSizeInput.text)
							{
								throw "Cannot convert to number the input fifth size: " + fifthSizeInput.text;
							}
							else
							{
								throw "Empty fifth size field.";
							}
						}
						else
						{
							fifthDeviation = TuningUtils.STANDARD_FIFTH - fifthSize;
							Logger.log("Fifth size: " + fifthSize + "; Fifth deviation: " + fifthDeviation);
							if (fifthSize < TuningUtils.SMALLEST_DIATONIC_FIFTH)
							{
								Logger.warning("Fifth smaller than the smallest diatonic fifth: " + fifthSize);
								fifthSizeDialogText.text = "The input fifth is smaller than "
									+ TuningUtils.SMALLEST_DIATONIC_FIFTH.toFixed(1) + " c, which is the smallest "
									+ "fifth size for which standard notation makes sense.\nThe plugin can work anyway"
									+ ", but it could produce some counterintuitive results.\nTune the score anyway?";
								fifthSizeDialog.open();
							}
							else if (fifthSize > TuningUtils.LARGEST_DIATONIC_FIFTH)
							{
								Logger.warning("Fifth larger than the largest diatonic fifth: " + fifthSize);
								fifthSizeDialogText.text = "The input fifth is larger than "
									+ TuningUtils.LARGEST_DIATONIC_FIFTH.toFixed(1) + " c, which is the largest "
									+ "fifth size for which standard notation makes sense.\nThe plugin can work anyway"
									+ ", but it could produce some counterintuitive results.\nTune the score anyway?";
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
						displayErrorMessage(error);
					}
				}
			}
		}

		RowLayout
		{
			spacing: defaultPadding;

			MU.StyledGroupBox
			{
				title: "EDOs";
				Layout.alignment: Qt.AlignTop;

				ColumnLayout
				{
					spacing: defaultPadding;
					Layout.alignment: Qt.AlignTop;

					MU.FlatButton
					{
						text: "5";

						onClicked:
						{
							setFifthSize(1200.0 / 5 * 3);
						}
					}

					MU.FlatButton
					{
						text: "7";

						onClicked:
						{
							setFifthSize(1200.0 / 7 * 4);
						}
					}

					MU.FlatButton
					{
						text: "12";

						onClicked:
						{
							setFifthSize(TuningUtils.STANDARD_FIFTH);
						}
					}

					MU.FlatButton
					{
						text: "17";

						onClicked:
						{
							setFifthSize(1200.0 / 17 * 10);
						}
					}

					MU.FlatButton
					{
						text: "19";

						onClicked:
						{
							setFifthSize(1200.0 / 19 * 11);
						}
					}

					MU.FlatButton
					{
						text: "26";

						onClicked:
						{
							setFifthSize(1200.0 / 26 * 15);
						}
					}

					MU.FlatButton
					{
						text: "29";

						onClicked:
						{
							setFifthSize(1200.0 / 29 * 17);
						}
					}

					MU.FlatButton
					{
						text: "31";

						onClicked:
						{
							setFifthSize(1200.0 / 31 * 18);
						}
					}

					MU.FlatButton
					{
						text: "41";

						onClicked:
						{
							setFifthSize(1200.0 / 41 * 24);
						}
					}

					MU.FlatButton
					{
						text: "43";

						onClicked:
						{
							setFifthSize(1200.0 / 43 * 25);
						}
					}

					MU.FlatButton
					{
						text: "50";

						onClicked:
						{
							setFifthSize(1200.0 / 50 * 29);
						}
					}
				}
			}

			MU.StyledGroupBox
			{
				title: "Meantones";
				Layout.alignment: Qt.AlignTop;

				ColumnLayout
				{
					spacing: defaultPadding;
					Layout.alignment: Qt.AlignTop;

					MU.FlatButton
					{
						text: "1/3 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 3);
						}
					}

					MU.FlatButton
					{
						text: "2/7 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 2 / 7);
						}
					}

					MU.FlatButton
					{
						text: "7/26 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 7 / 26);
						}
					}

					MU.FlatButton
					{
						text: "1/4 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 4);
						}
					}

					MU.FlatButton
					{
						text: "2/9 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA * 2 / 9);
						}
					}

					MU.FlatButton
					{
						text: "1/5 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 5);
						}
					}

					MU.FlatButton
					{
						text: "1/6 Comma";

						onClicked:
						{
							setFifthSize(TuningUtils.JUST_FIFTH - TuningUtils.SYNTONIC_COMMA / 6);
						}
					}

					MU.FlatButton
					{
						text: "Golden";

						onClicked:
						{
							setFifthSize(600.0 / 11 * (15 - Math.sqrt(5)));
						}
					}

					MU.FlatButton
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

				MU.StyledGroupBox
				{
					title: "Other Tunings";
					Layout.alignment: Qt.AlignTop;

					ColumnLayout
					{
						spacing: defaultPadding;
						Layout.alignment: Qt.AlignTop;

						MU.FlatButton
						{
							text: "Pythagorean";

							onClicked:
							{
								setFifthSize(TuningUtils.JUST_FIFTH);
							}
						}
					}
				}

				MU.StyledGroupBox
				{
					title: "Custom Tunings";
					Layout.alignment: Qt.AlignTop;

					ColumnLayout
					{
						spacing: defaultPadding;
						Layout.alignment: Qt.AlignTop;

						MU.FlatButton
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

						MU.FlatButton
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

						MU.FlatButton
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

						MU.FlatButton
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

						MU.FlatButton
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

						MU.FlatButton
						{
							id: addCustom;
							text: "Add Custom";

							onClicked:
							{
								newCustomTuningDialog.open();
							}
						}

						MU.FlatButton
						{
							id: deleteCustom;
							text: "Delete Custom";

							onClicked:
							{
								deleteCustomTuningDialog.open();
							}
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

			Logger.initialise(logggerId, parseInt(settings["LogLevel"]));
			Logger.log(title + " - v" + version);

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
		fifthSize = ("" + fifthSize).trim();
		Logger.log("New custom tuning name: " + tuningName + "; Fifth size: " + fifthSize);
		if ((fifthSize == "") || isNaN(fifthSize))
		{
			throw "Invalid custom fifth size: " + fifthSize;
		}

		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		if (fileContent.hasOwnProperty(tuningName))
		{
			throw "Custom tuning name already present: " + tuningName;
		}
		fileContent[tuningName] = fifthSize;
		SettingsIO.writeTsvFile(fileContent, customTuningsId);

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

		for (var customTuningCheckBox of deleteCustomTuningsCheckBoxes)
		{
			customTuningCheckBox.checked = false;
		}

		var fileContent = SettingsIO.readTsvFile(customTuningsId);
		for (var tuningName of tuningsToDelete)
		{
			Logger.trace("Deleting tuning: " + tuningName);
			delete fileContent[tuningName];
		}
		SettingsIO.writeTsvFile(fileContent, customTuningsId);

		Logger.log("Custom tunings deleted successfully.");
		Logger.writeLogs();
	}

	/**
	 * Set the fifth size text box to the specified value.
	 */
	function setFifthSize(fifthSize)
	{
		Logger.log("Setting fifth size to: " + fifthSize);
		fifthSizeInput.text = fifthSize;
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

		referenceNote = referenceNoteNameId.currentText + referenceNoteAccidentalId.currentText.replace("-", "");
		Logger.log("Reference note changed to: " + referenceNote);
		Logger.writeLogs();
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
