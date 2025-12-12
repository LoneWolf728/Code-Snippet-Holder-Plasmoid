import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils as KCM
import Qt.labs.platform as Platform

KCM.SimpleKCM {
    id: page
    
    property string cfg_customFilePath
    property int cfg_fontSize
    
    Kirigami.FormLayout {
        
        // Custom File Path Selection
        RowLayout {
            Kirigami.FormData.label: "Custom Storage File:"
            
            PlasmaComponents3.TextField {
                id: pathField
                placeholderText: "/path/to/my_snippets.json"
                Layout.fillWidth: true
                text: plasmoid.configuration.customFilePath
                onTextChanged: {
                    plasmoid.configuration.customFilePath = text
                    cfg_customFilePath = text
                }
            }
            
            PlasmaComponents3.Button {
                icon.name: "folder-open"
                text: "Browse..."
                onClicked: fileDialog.open()
            }
        }
        
        PlasmaComponents3.Label {
            text: "Leave empty to use default internal storage. If set, snippets will be loaded from and saved to this file."
            font.italic: true
            opacity: 0.7
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // Font Size Configuration
        QQC2.SpinBox {
            id: fontSizeSpin
            Kirigami.FormData.label: "Font Size:"
            from: 6
            to: 32
            stepSize: 1
            value: plasmoid.configuration.fontSize
            onValueModified: {
                plasmoid.configuration.fontSize = value
                cfg_fontSize = value
            }
        }
    }
    
    Platform.FileDialog {
        id: fileDialog
        title: "Select Storage File"
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        fileMode: Platform.FileDialog.SaveFile
        onAccepted: {
            var path = file.toString().replace(/^file:\/\//, '')
            pathField.text = path
        }
    }
}