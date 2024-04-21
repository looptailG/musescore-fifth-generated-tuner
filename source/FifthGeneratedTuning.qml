import QtQuick 2.0
import QtQuick.Controls 1.3
import QtQuick.Controls.Styles 1.3
import MuseScore 3.0

MuseScore
{
	title: qsTr("Fifth Generated Tuner");
	categoryCode: "playback";
	description: "Retune the selection, or the whole score if nothing is selected, using the specified size for the fifth.";
	version: "0.1.0";
	
	pluginType: "dialog";
	width: 800;
	height: 500;
	
	// Size in cents of a justly tuned perfect fifth.
	property var justFifth: 1200.0 * Math.log2(3 / 2);
	// Size in cents of the syntonic comma.
	property var syntonicComma: 1200.0 * Math.log2(81 / 80);
	property var fifthSize: 700.0;
	
	Rectangle
	{
		anchors.fill: parent;
		
		Row
		{
			y: 10;
			spacing: 10;
			
			Text
			{
				text: "Size of the fifth in cents:";
				font.pixelSize: 30;
			}
			
			TextField
			{
				placeholderText: qsTr("685.7 - 720.0");
				id: sizeField;
				width: 180;
				height: 30;
			}
			
			Button
			{
				width: 140;
				height: 25;
				text: "Tune";
				onClicked:
				{
					fifthSize = parseFloat(sizeField.text);
					
					quit();
				}
			}
		}
		
		Row
		{
			y: 75;
			spacing: 5;
			
			Text
			{
				text: "Tunings";
				font.pixelSize: 15;
			}
			
			Column
			{
				y: 75;
				spacing: 15;
				
				Text
				{
					text: "EDOs";
					font.pixelSize: 15;
				}
				
				Button
				{
					width: 35;
					height: 20;
					text: "7";
					onClicked:
					{
						sizeField.text = 1200.0 / 7 * 4;
					}
				}
			}
			
			Column
			{
				y: 75;
				spacing: 15;
				
				Text
				{
					text: "Meantones";
					font.pixelSize: 15;
				}
				
				Button
				{
					width: 35;
					height: 20;
					text: "1/3 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 3;
					}
				}
				
				Button
				{
					width: 35;
					height: 20;
					text: "1/4 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 4;
					}
				}
				
				Button
				{
					width: 35;
					height: 20;
					text: "1/5 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 5;
					}
				}
				
				Button
				{
					width: 35;
					height: 20;
					text: "1/6 comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 6;
					}
				}
			}
			
			Column
			{
				y: 75;
				spacing: 15;
				
				Text
				{
					text: "Other";
					font.pixelSize: 15;
				}
				
				Button
				{
					width: 35;
					height: 20;
					text: "Pythagorean";
					onClicked:
					{
						sizeField.text = justFifth;
					}
				}
			}
		}
	}
	
	onRun:
	{
		if (typeof curScore === "undefined")
		{
			quit();
		}
	}
}