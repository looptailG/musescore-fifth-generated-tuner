import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Muse.Ui
import Muse.UiComponents as MU
import MuseScore 3.0

MuseScore
{
	title: "Fifth Generated Tuner";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified fifth size.";
	categoryCode: "playback";
	thumbnailName: "FifthGeneratedTunerThumbnail.png";
	version: "1.3.4";
	pluginType: "dialog";

	id: root;
	width: childrenRect.width + 20;
	height: childrenRect.height + 20;

	ColumnLayout
	{
		anchors.centerIn: parent;
		spacing: 10;

		RowLayout
		{
			spacing: 10;

			MU.StyledGroupBox
			{
				title: "Fifth Size (in cents)";
				width: fifthSizeInput.width + 25;
				Layout.alignment: Qt.AlignVCenter

				ColumnLayout
				{
					spacing: 10;

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
				width: referenceNoteNameId.width + referenceNoteAccidentalId.width + 35;
				Layout.alignment: Qt.AlignVCenter

				RowLayout
				{
					spacing: 10;

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
				Layout.alignment: Qt.AlignVCenter

				onClicked:
				{
				}
			}
		}
	}
}