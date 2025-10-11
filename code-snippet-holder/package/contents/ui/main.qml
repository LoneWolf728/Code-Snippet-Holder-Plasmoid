import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

PlasmoidItem {
    id: root
    
    // This makes it show as an icon in the panel
    preferredRepresentation: compactRepresentation
    
    // Store snippets in plasmoid configuration
    property var snippets: []
    property bool isPinned: false
    
    // Control whether clicking outside closes the popup
    hideOnWindowDeactivate: !isPinned
    
    Component.onCompleted: {
        loadSnippets()
    }
    
    function loadSnippets() {
        var saved = plasmoid.configuration.snippetsData
        if (saved) {
            try {
                snippets = JSON.parse(saved)
            } catch (e) {
                snippets = []
            }
        }
        if (snippets.length === 0) {
            snippets = [
                {
                    title: "Example Snippet",
                    code: "console.log('Hello World!');"
                }
            ]
        }
        snippetModel.clear()
        for (var i = 0; i < snippets.length; i++) {
            snippetModel.append(snippets[i])
        }
        filterSnippets("")
    }
    
    function saveSnippets() {
        snippets = []
        for (var i = 0; i < snippetModel.count; i++) {
            snippets.push({
                title: snippetModel.get(i).title,
                code: snippetModel.get(i).code
            })
        }
        plasmoid.configuration.snippetsData = JSON.stringify(snippets)
    }
    
    ListModel {
        id: snippetModel
    }
    
    ListModel {
        id: filteredModel
    }
    
    function filterSnippets(searchText) {
        filteredModel.clear()
        if (searchText === "") {
            for (var i = 0; i < snippetModel.count; i++) {
                filteredModel.append(snippetModel.get(i))
            }
        } else {
            var lowerSearch = searchText.toLowerCase()
            for (var j = 0; j < snippetModel.count; j++) {
                var snippet = snippetModel.get(j)
                if (snippet.title.toLowerCase().includes(lowerSearch) || 
                    snippet.code.toLowerCase().includes(lowerSearch)) {
                    filteredModel.append(snippet)
                }
            }
        }
    }
    
    // Compact representation - the icon that appears in the panel
    compactRepresentation: Kirigami.Icon {
        source: "code-context"
        active: compactMouse.containsMouse
        
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }
    
    // Full representation - the popup window
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 25
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        Layout.preferredWidth: Kirigami.Units.gridUnit * 30
        Layout.preferredHeight: Kirigami.Units.gridUnit * 25
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            
            // Header with Add button
            RowLayout {
                Layout.fillWidth: true
                
                Kirigami.Heading {
                    text: "Code Snippets"
                    level: 3
                    Layout.fillWidth: true
                }
                
                PlasmaComponents3.Button {
                    icon.name: isPinned ? "window-unpin" : "window-pin"
                    text: isPinned ? "Unpin" : "Pin"
                    onClicked: {
                        isPinned = !isPinned
                    }
                    PlasmaComponents3.ToolTip {
                        text: isPinned ? "Unpin window" : "Pin window to keep it open"
                    }
                }
                
                PlasmaComponents3.Button {
                    icon.name: "list-add"
                    text: "Add"
                    onClicked: {
                        editDialog.editIndex = -1
                        editDialog.editTitle = "New Snippet"
                        editDialog.editCode = "// Your code here"
                        editDialog.open()
                    }
                }
            }
            
            // Search bar
            PlasmaComponents3.TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search snippets..."
                clearButtonShown: true
                onTextChanged: filterSnippets(text)
            }
            
            // Snippet List
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ListView {
                    id: snippetListView
                    model: filteredModel
                    spacing: Kirigami.Units.smallSpacing
                    clip: true
                    
                    delegate: Kirigami.AbstractCard {
                        width: snippetListView.width - Kirigami.Units.smallSpacing * 2
                        
                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Kirigami.Heading {
                                    text: model.title
                                    level: 4
                                    Layout.fillWidth: true
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "edit-copy"
                                    text: "Copy"
                                    onClicked: {
                                        // Find the actual index in snippetModel
                                        var actualIndex = -1
                                        for (var i = 0; i < snippetModel.count; i++) {
                                            if (snippetModel.get(i).title === model.title && 
                                                snippetModel.get(i).code === model.code) {
                                                actualIndex = i
                                                break
                                            }
                                        }
                                        if (actualIndex >= 0) {
                                            clipboardHelper.text = snippetModel.get(actualIndex).code
                                            clipboardHelper.selectAll()
                                            clipboardHelper.copy()
                                            showNotification("Copied!")
                                        }
                                    }
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "document-edit"
                                    text: "Edit"
                                    onClicked: {
                                        // Find the actual index in snippetModel
                                        var actualIndex = -1
                                        for (var i = 0; i < snippetModel.count; i++) {
                                            if (snippetModel.get(i).title === model.title && 
                                                snippetModel.get(i).code === model.code) {
                                                actualIndex = i
                                                break
                                            }
                                        }
                                        if (actualIndex >= 0) {
                                            editDialog.editIndex = actualIndex
                                            editDialog.editTitle = model.title
                                            editDialog.editCode = model.code
                                            editDialog.open()
                                        }
                                    }
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "delete"
                                    text: "Delete"
                                    onClicked: {
                                        // Find the actual index in snippetModel
                                        var actualIndex = -1
                                        for (var i = 0; i < snippetModel.count; i++) {
                                            if (snippetModel.get(i).title === model.title && 
                                                snippetModel.get(i).code === model.code) {
                                                actualIndex = i
                                                break
                                            }
                                        }
                                        if (actualIndex >= 0) {
                                            snippetModel.remove(actualIndex)
                                            saveSnippets()
                                            filterSnippets(searchField.text)
                                        }
                                    }
                                }
                            }
                            
                            QQC2.ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(codeText.contentHeight + 20, 150)
                                
                                QQC2.TextArea {
                                    id: codeText
                                    text: model.code
                                    readOnly: true
                                    wrapMode: Text.Wrap
                                    font.family: "monospace"
                                    background: Rectangle {
                                        color: Kirigami.Theme.alternateBackgroundColor
                                        radius: 3
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Notification
            PlasmaComponents3.Label {
                id: notification
                Layout.alignment: Qt.AlignHCenter
                visible: false
                text: ""
                color: Kirigami.Theme.positiveTextColor
                
                SequentialAnimation {
                    id: notificationAnimation
                    PropertyAnimation {
                        target: notification
                        property: "visible"
                        to: true
                        duration: 0
                    }
                    PauseAnimation {
                        duration: 2000
                    }
                    PropertyAnimation {
                        target: notification
                        property: "visible"
                        to: false
                        duration: 0
                    }
                }
            }
        }
        
        // Hidden text field for clipboard operations
        TextEdit {
            id: clipboardHelper
            visible: false
        }
        
        // Edit Dialog
        QQC2.Dialog {
            id: editDialog
            title: editIndex === -1 ? "Add Snippet" : "Edit Snippet"
            modal: true
            standardButtons: QQC2.Dialog.Save | QQC2.Dialog.Cancel
            
            property int editIndex: -1
            property string editTitle: ""
            property string editCode: ""
            
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Math.min(parent.width * 0.9, Kirigami.Units.gridUnit * 30)
            height: Math.min(parent.height * 0.8, Kirigami.Units.gridUnit * 25)
            
            onAccepted: {
                if (editIndex === -1) {
                    snippetModel.append({
                        title: titleField.text,
                        code: codeField.text
                    })
                } else {
                    snippetModel.set(editIndex, {
                        title: titleField.text,
                        code: codeField.text
                    })
                }
                saveSnippets()
                filterSnippets(searchField.text)
            }
            
            onOpened: {
                titleField.text = editTitle
                codeField.text = editCode
                titleField.forceActiveFocus()
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                
                PlasmaComponents3.Label {
                    text: "Title:"
                }
                
                PlasmaComponents3.TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Snippet title..."
                }
                
                PlasmaComponents3.Label {
                    text: "Code:"
                }
                
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    QQC2.TextArea {
                        id: codeField
                        placeholderText: "// Your code here..."
                        wrapMode: Text.Wrap
                        font.family: "monospace"
                    }
                }
            }
        }
    }
    
    function showNotification(message) {
        notification.text = message
        notificationAnimation.restart()
    }
}