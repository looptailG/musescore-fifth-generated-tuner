import QtQuick
import QtQuick.Controls

ComboBox
{
	id: root;

	property font comboBoxFont;

	Layout.preferredWidth: 80;
	padding: 10;
	rightPadding: referenceNoteNameIndicatorId.width + root.padding * 2;

	contentItem: Text
	{
		text: root.displayText;
		font: root.comboBoxFont;
		color: ui.theme.fontPrimaryColor;
		elide: Text.ElideRight;
		verticalAlignment: Text.AlignVCenter;
	}

	background: Rectangle
	{
		color: ui.theme.buttonColor;
		border.color: ui.theme.backgroundSecondaryColor;
	}

	indicator: Text
	{
		id: indicatorId;
		text: "▼";
		color: ui.theme.fontPrimaryColor;
		x: root.width - indicatorId.width - defaultPadding;
		y: (root.height - indicatorId.height) / 2;
	}

	delegate: ItemDelegate
	{
		width: root.width;

		contentItem: Text
		{
			text: modelData;
			font: root.comboBoxFont;
			color: ui.theme.fontPrimaryColor;
			verticalAlignment: Text.AlignVCenter;
			elide: Text.ElideRight;
		}

		background: Rectangle
		{
			color: ui.theme.buttonColor;
		}
	}
}
