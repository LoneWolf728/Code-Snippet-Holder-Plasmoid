import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    
    // This makes it show as an icon in the panel
    preferredRepresentation: compactRepresentation
    
    // Store groups and snippets in plasmoid configuration
    property var groups: []
    property var snippets: []
    property bool isPinned: false
    property int fontSize: 10
    property var currentPath: [] // Stack to track navigation path
    property int currentGroupId: -1 // -1 means root level
    property int pathDepth: 0 // Track navigation depth for UI reactivity
    
    // Control whether clicking outside closes the popup
    hideOnWindowDeactivate: !isPinned
    
    Component.onCompleted: {
        loadData()
        fontSize = plasmoid.configuration.fontSize || 10
    }
    
    onFontSizeChanged: {
        plasmoid.configuration.fontSize = fontSize
    }
    
    function loadData() {
        // Load groups
        var savedGroups = plasmoid.configuration.groupsData
        if (savedGroups) {
            try {
                groups = JSON.parse(savedGroups)
            } catch (e) {
                groups = []
            }
        }
        
        // Load snippets
        var savedSnippets = plasmoid.configuration.snippetsData
        if (savedSnippets) {
            try {
                snippets = JSON.parse(savedSnippets)
            } catch (e) {
                snippets = []
            }
        }
        
        // Add example data if empty
        if (groups.length === 0 && snippets.length === 0) {
            groups = [
                {
                    id: 1,
                    name: "JavaScript",
                    parentId: -1
                }
            ]
            snippets = [
                {
                    id: 1,
                    title: "Example Snippet",
                    code: "console.log('Hello World!');",
                    groupId: 1
                },
                {
                    id: 2,
                    title: "Ungrouped Snippet",
                    code: "// This snippet has no group",
                    groupId: -1
                }
            ]
            saveData()
        }
        
        refreshView()
    }
    
    function saveData() {
        plasmoid.configuration.groupsData = JSON.stringify(groups)
        plasmoid.configuration.snippetsData = JSON.stringify(snippets)
    }
    
    function refreshView() {
        displayModel.clear()
        
        var searchText = ""
        if (typeof searchField !== 'undefined' && searchField) {
            searchText = searchField.text.toLowerCase()
        }
        
        // If searching, show all matching items
        if (searchText !== "") {
            // Add matching groups
            for (var i = 0; i < groups.length; i++) {
                var group = groups[i]
                if (group.name.toLowerCase().includes(searchText)) {
                    displayModel.append({
                        itemType: "group",
                        itemId: group.id,
                        title: group.name,
                        code: "",
                        groupId: group.parentId
                    })
                }
            }
            
            // Add matching snippets
            for (var j = 0; j < snippets.length; j++) {
                var snippet = snippets[j]
                if (snippet.title.toLowerCase().includes(searchText) || 
                    snippet.code.toLowerCase().includes(searchText)) {
                    displayModel.append({
                        itemType: "snippet",
                        itemId: snippet.id,
                        title: snippet.title,
                        code: snippet.code,
                        groupId: snippet.groupId
                    })
                }
            }
        } else {
            // Show items at current level: groups first, then snippets
            // Add groups at current level
            for (var k = 0; k < groups.length; k++) {
                var grp = groups[k]
                if (grp.parentId === currentGroupId) {
                    displayModel.append({
                        itemType: "group",
                        itemId: grp.id,
                        title: grp.name,
                        code: "",
                        groupId: grp.parentId
                    })
                }
            }
            
            // Add snippets at current level
            for (var l = 0; l < snippets.length; l++) {
                var snip = snippets[l]
                if (snip.groupId === currentGroupId) {
                    displayModel.append({
                        itemType: "snippet",
                        itemId: snip.id,
                        title: snip.title,
                        code: snip.code,
                        groupId: snip.groupId
                    })
                }
            }
        }
    }
    
    function getNextId(array) {
        var maxId = 0
        for (var i = 0; i < array.length; i++) {
            if (array[i].id > maxId) {
                maxId = array[i].id
            }
        }
        return maxId + 1
    }
    
    function navigateToGroup(groupId, groupName) {
        currentPath.push({id: currentGroupId, name: getCurrentGroupName()})
        currentGroupId = groupId
        pathDepth = currentPath.length
        refreshView()
    }
    
    function navigateBack() {
        if (currentPath.length > 0) {
            var prev = currentPath.pop()
            currentGroupId = prev.id
            pathDepth = currentPath.length
            refreshView()
        }
    }
    
    function getCurrentGroupName() {
        if (currentGroupId === -1) {
            return "Root"
        }
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].id === currentGroupId) {
                return groups[i].name
            }
        }
        return "Unknown"
    }
    
    function findGroupById(groupId) {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].id === groupId) {
                return i
            }
        }
        return -1
    }
    
    function findSnippetById(snippetId) {
        for (var i = 0; i < snippets.length; i++) {
            if (snippets[i].id === snippetId) {
                return i
            }
        }
        return -1
    }
    
    // DataSource for executing shell commands
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        // Flag to distinguish import vs export operations
        property bool isImporting: false
        
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            var exitCode = data["exit code"]
            
            disconnectSource(sourceName)
            
            if (isImporting) {
                isImporting = false
                if (exitCode === 0 && stdout) {
                    try {
                        var importedData = JSON.parse(stdout)
                        if (importedData.groups && importedData.snippets) {
                            groups = importedData.groups
                            snippets = importedData.snippets
                            saveData()
                            refreshView()
                            showNotification("Imported successfully!")
                        } else {
                            showNotification("Invalid file format!")
                        }
                    } catch (e) {
                        showNotification("Error parsing file: " + e)
                    }
                } else {
                    showNotification("Failed to read file: " + (stderr || "No data"))
                }
            } else {
                // Export operation
                if (exitCode === 0) {
                    showNotification("Exported successfully!")
                } else {
                    showNotification("Export failed: " + (stderr || "Unknown error"))
                }
            }
        }
    }
    
    function exportData(fileUrl) {
        var exportData = {
            version: "1.0",
            groups: groups,
            snippets: snippets
        }
        var jsonData = JSON.stringify(exportData, null, 2) // Added formatting for readability
        
        // Convert file:// URL to path
        var filePath = fileUrl.toString().replace(/^file:\/\//, '')
        
        // Escape the JSON data properly for shell
        var escapedData = jsonData.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\$/g, '\\$').replace(/`/g, '\\`')
        
        // Use printf to handle special characters better than echo
        var cmd = 'printf "%s" "' + escapedData + '" > "' + filePath + '"'
        
        executable.connectSource(cmd)
    }
    
    function importData(fileUrl) {
        // Convert file:// URL to path
        var filePath = fileUrl.toString().replace(/^file:\/\//, '')
        
        // Mark next operation as import
        executable.isImporting = true
        
        // Use cat to read file (no custom prefix)
        var cmd = "cat '" + filePath + "'"
        executable.connectSource(cmd)
    }
    
    ListModel {
        id: displayModel
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
                
                PlasmaComponents3.Button {
                    icon.name: "go-previous"
                    visible: pathDepth > 0
                    onClicked: navigateBack()
                    PlasmaComponents3.ToolTip {
                        text: "Go back to parent"
                    }
                }
                
                Kirigami.Heading {
                    text: currentGroupId === -1 ? "Code Snippets" : getCurrentGroupName()
                    level: 3
                    Layout.fillWidth: true
                    font.pixelSize: fontSize + 4
                }
                
                PlasmaComponents3.Button {
                    icon.name: "zoom-out"
                    text: "-"
                    enabled: fontSize > 6
                    onClicked: {
                        if (fontSize > 6) fontSize--
                    }
                    PlasmaComponents3.ToolTip {
                        text: "Decrease font size"
                    }
                }
                
                PlasmaComponents3.Button {
                    icon.name: "zoom-in"
                    text: "+"
                    enabled: fontSize < 24
                    onClicked: {
                        if (fontSize < 24) fontSize++
                    }
                    PlasmaComponents3.ToolTip {
                        text: "Increase font size"
                    }
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
                    icon.name: "document-import"
                    text: "Import"
                    onClicked: {
                        importFileDialog.open()
                    }
                    PlasmaComponents3.ToolTip {
                        text: "Import snippets from file"
                    }
                }
                
                PlasmaComponents3.Button {
                    icon.name: "document-export"
                    text: "Export"
                    onClicked: {
                        exportFileDialog.open()
                    }
                    PlasmaComponents3.ToolTip {
                        text: "Export snippets to file"
                    }
                }
                
                PlasmaComponents3.Button {
                    icon.name: "folder-new"
                    text: "New Group"
                    onClicked: {
                        groupDialog.editIndex = -1
                        groupDialog.editName = "New Group"
                        groupDialog.open()
                    }
                    PlasmaComponents3.ToolTip {
                        text: "Create a new group"
                    }
                }
                
                PlasmaComponents3.Button {
                    icon.name: "list-add"
                    text: "New Snippet"
                    onClicked: {
                        editDialog.editIndex = -1
                        editDialog.editTitle = "New Snippet"
                        editDialog.editCode = "// Your code here"
                        editDialog.open()
                    }
                    PlasmaComponents3.ToolTip {
                        text: "Create a new snippet"
                    }
                }
            }
            
            // Search bar
            PlasmaComponents3.TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search snippets and groups..."
                clearButtonShown: true
                onTextChanged: refreshView()
                font.pixelSize: fontSize
            }
            
            // Display List
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ListView {
                    id: displayListView
                    model: displayModel
                    spacing: Kirigami.Units.smallSpacing
                    clip: true
                    
                    delegate: Kirigami.AbstractCard {
                        width: displayListView.width - Kirigami.Units.smallSpacing * 2
                        
                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            
                            // Group representation
                            RowLayout {
                                Layout.fillWidth: true
                                visible: model.itemType === "group"
                                
                                Kirigami.Icon {
                                    source: "folder"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                
                                Kirigami.Heading {
                                    text: model.title
                                    level: 4
                                    Layout.fillWidth: true
                                    font.pixelSize: fontSize + 2
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: navigateToGroup(model.itemId, model.title)
                                    }
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "document-edit"
                                    text: "Rename"
                                    font.pixelSize: fontSize
                                    onClicked: {
                                        var idx = findGroupById(model.itemId)
                                        if (idx >= 0) {
                                            groupDialog.editIndex = idx
                                            groupDialog.editName = model.title
                                            groupDialog.open()
                                        }
                                    }
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "delete"
                                    text: "Delete"
                                    font.pixelSize: fontSize
                                    onClicked: {
                                        var idx = findGroupById(model.itemId)
                                        if (idx >= 0) {
                                            // Move child items to parent
                                            var deletedGroupId = groups[idx].id
                                            var parentGroupId = groups[idx].parentId
                                            
                                            // Move child groups
                                            for (var i = 0; i < groups.length; i++) {
                                                if (groups[i].parentId === deletedGroupId) {
                                                    groups[i].parentId = parentGroupId
                                                }
                                            }
                                            
                                            // Move snippets in this group
                                            for (var j = 0; j < snippets.length; j++) {
                                                if (snippets[j].groupId === deletedGroupId) {
                                                    snippets[j].groupId = parentGroupId
                                                }
                                            }
                                            
                                            groups.splice(idx, 1)
                                            saveData()
                                            refreshView()
                                        }
                                    }
                                }
                            }
                            
                            // Snippet representation
                            RowLayout {
                                Layout.fillWidth: true
                                visible: model.itemType === "snippet"
                                
                                Kirigami.Icon {
                                    source: "text-x-generic"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                
                                Kirigami.Heading {
                                    text: model.title
                                    level: 4
                                    Layout.fillWidth: true
                                    font.pixelSize: fontSize + 2
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "edit-copy"
                                    text: "Copy"
                                    font.pixelSize: fontSize
                                    onClicked: {
                                        clipboardHelper.text = model.code
                                        clipboardHelper.selectAll()
                                        clipboardHelper.copy()
                                        showNotification("Copied!")
                                    }
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "document-edit"
                                    text: "Edit"
                                    font.pixelSize: fontSize
                                    onClicked: {
                                        var idx = findSnippetById(model.itemId)
                                        if (idx >= 0) {
                                            editDialog.editIndex = idx
                                            editDialog.editTitle = model.title
                                            editDialog.editCode = model.code
                                            editDialog.open()
                                        }
                                    }
                                }
                                
                                PlasmaComponents3.Button {
                                    icon.name: "delete"
                                    text: "Delete"
                                    font.pixelSize: fontSize
                                    onClicked: {
                                        var idx = findSnippetById(model.itemId)
                                        if (idx >= 0) {
                                            snippets.splice(idx, 1)
                                            saveData()
                                            refreshView()
                                        }
                                    }
                                }
                            }
                            
                            // Code display (only for snippets)
                            QQC2.ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(codeText.contentHeight + 20, 150)
                                visible: model.itemType === "snippet"
                                
                                QQC2.TextArea {
                                    id: codeText
                                    text: model.code
                                    readOnly: true
                                    wrapMode: Text.Wrap
                                    font.family: "monospace"
                                    font.pixelSize: fontSize
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
                font.pixelSize: fontSize
                
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
        
        // Group Dialog
        QQC2.Dialog {
            id: groupDialog
            title: editIndex === -1 ? "New Group" : "Rename Group"
            modal: true
            standardButtons: QQC2.Dialog.Save | QQC2.Dialog.Cancel
            
            property int editIndex: -1
            property string editName: ""
            
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Math.min(parent.width * 0.6, Kirigami.Units.gridUnit * 20)
            
            onAccepted: {
                if (editIndex === -1) {
                    // Create new group
                    groups.push({
                        id: getNextId(groups),
                        name: groupNameField.text,
                        parentId: currentGroupId
                    })
                } else {
                    // Rename existing group
                    groups[editIndex].name = groupNameField.text
                }
                saveData()
                refreshView()
            }
            
            onOpened: {
                groupNameField.text = editName
                groupNameField.forceActiveFocus()
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                
                PlasmaComponents3.Label {
                    text: "Group Name:"
                    font.pixelSize: fontSize
                }
                
                PlasmaComponents3.TextField {
                    id: groupNameField
                    Layout.fillWidth: true
                    placeholderText: "Enter group name..."
                    font.pixelSize: fontSize
                }
            }
        }
        
        // Edit Snippet Dialog
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
                    // Create new snippet
                    snippets.push({
                        id: getNextId(snippets),
                        title: titleField.text,
                        code: codeField.text,
                        groupId: currentGroupId
                    })
                } else {
                    // Update existing snippet
                    snippets[editIndex].title = titleField.text
                    snippets[editIndex].code = codeField.text
                }
                saveData()
                refreshView()
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
                    font.pixelSize: fontSize
                }
                
                PlasmaComponents3.TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Snippet title..."
                    font.pixelSize: fontSize
                }
                
                PlasmaComponents3.Label {
                    text: "Code:"
                    font.pixelSize: fontSize
                }
                
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    QQC2.TextArea {
                        id: codeField
                        placeholderText: "// Your code here..."
                        wrapMode: Text.Wrap
                        font.family: "monospace"
                        font.pixelSize: fontSize
                    }
                }
            }
        }
        
        // Export File Dialog
        Platform.FileDialog {
            id: exportFileDialog
            title: "Export Snippets"
            fileMode: Platform.FileDialog.SaveFile
            nameFilters: ["JSON files (*.json)"]
            defaultSuffix: "json"
            
            onAccepted: {
                exportData(file)
            }
        }
        
        // Import File Dialog
        Platform.FileDialog {
            id: importFileDialog
            title: "Import Snippets"
            fileMode: Platform.FileDialog.OpenFile
            nameFilters: ["JSON files (*.json)"]
            
            onAccepted: {
                importData(file)
            }
        }
    }
    
    function showNotification(message) {
        notification.text = message
        notificationAnimation.restart()
    }
}