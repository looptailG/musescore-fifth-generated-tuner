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
		id: errorDialog;

		contentItem: MU.StyledTextLabel
		{
			id: errorText;
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
							currentIndex = index;
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
							currentIndex = index;
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
	}

	/**
	 * Add the input custom tuning to the configuration file.
	 */
	function newCustomTuning(tuningName, fifthSize)
	{
	}

	/**
	 * Delete the tunings with the specified input names from the configuration
	 * file.
	 */
	function deleteCustomTunings(tuningsToDelete)
	{
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
}