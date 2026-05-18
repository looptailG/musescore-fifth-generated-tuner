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
		
		Row
		{
			spacing: 10;
			
			MU.StyledGroupBox
			{
				title: "Fifth Size (in cents)";
				width: 200;
				
				ColumnLayout
				{
					spacing: 10;

					TextArea
					{
						placeholderText: qsTr("TBD");
						id: fifthSizeField;
					}
				}
			}
			
			MU.StyledGroupBox
			{
				title: "Reference Note";
				width: 200;
			}
		}
	}
}