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
	height: 800;
	
	property int buttonWidth: 100;
	property int buttonHeight: 40;
	
	// Size in cents of a justly tuned perfect fifth.
	property var justFifth: 1200.0 * Math.log2(3 / 2);
	// Size in cents of a 12EDO perfect fifth.
	property var defaultFifth: 700.0;
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
					width: buttonWidth;
					height: buttonHeight;
					text: "5";
					onClicked:
					{
						sizeField.text = 1200.0 / 5 * 3;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "7";
					onClicked:
					{
						sizeField.text = 1200.0 / 7 * 4;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "12";
					onClicked:
					{
						sizeField.text = defaultFifth;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "17";
					onClicked:
					{
						sizeField.text = 1200.0 / 17 * 10;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "19";
					onClicked:
					{
						sizeField.text = 1200.0 / 19 * 11;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "26";
					onClicked:
					{
						sizeField.text = 1200.0 / 26 * 15;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "29";
					onClicked:
					{
						sizeField.text = 1200.0 / 29 * 17;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "31";
					onClicked:
					{
						sizeField.text = 1200.0 / 31 * 18;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "43";
					onClicked:
					{
						sizeField.text = 1200.0 / 43 * 25;
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
					width: buttonWidth;
					height: buttonHeight;
					text: "1/3 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 3;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "2/7 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma * 2 / 7;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/4 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 4;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/5 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 5;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "1/6 Comma";
					onClicked:
					{
						sizeField.text = justFifth - syntonicComma / 6;
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Golden Meantone";
					onClicked:
					{
						sizeField.text = 600.0 / 11 * (15 - Math.sqrt(5));
					}
				}
				
				Button
				{
					width: buttonWidth;
					height: buttonHeight;
					text: "Tungsten Meantone";
					onClicked:
					{
						sizeField.text = 600.0 * (Math.sqrt(10) - 2);
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
					width: buttonWidth;
					height: buttonHeight;
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