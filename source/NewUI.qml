import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FileIO
import Muse.Ui
import Muse.UiComponents as MU
import MuseScore 3.0
import "Logger.js" as Logger
import "SettingsIO.js" as SettingsIO

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

	FileIO
	{
		id: settingsId;
		source: Qt.resolvedUrl(".").toString() + "Settings.tsv";
	}

	FileIO
	{
		id: logggerId;
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
						placeholderText: qsTr("TBD");
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

			ColumnLayout
			{
				spacing: defaultPadding;
				Layout.alignment: Qt.AlignTop;

				MU.StyledGroupBox
				{
					title: "EDOs";
					Layout.alignment: Qt.AlignTop;

					MU.FlatButton
					{
						text: "5";

						onClicked:
						{
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
					title: "Meantones";
					Layout.alignment: Qt.AlignTop;

					MU.FlatButton
					{
						text: "1/3 Comma";

						onClicked:
						{
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
					title: "Others";
					Layout.alignment: Qt.AlignTop;

					MU.FlatButton
					{
						text: "Pythagorean";

						onClicked:
						{
						}
					}
				}

				MU.StyledGroupBox
				{
					title: "Custom";
					Layout.alignment: Qt.AlignTop;
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
}