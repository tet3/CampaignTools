({
    handleSourceChange: function(component, event, helper) {
        var sourceSegment = event.getParam("value");
        helper.updateReportColumns(component, helper, sourceSegment);
    },

    handleSourceType: function(component) {
        var selectCmp = component.find("sourceType");
        var source = component.get('v.source');
        source.segmentType = selectCmp.get("v.value");
        component.set("v.source", source);
    },

    handleColumnName: function(component) {
        var selectCmp = component.find("columnName");
        var source = component.get('v.source');
        var columnName = selectCmp.get("v.value");
        if (columnName === '') {
            delete source.columnName;
        } else {
            source.columnName = columnName;
        }
        component.set("v.source", source);
    },

    deleteSource: function (component, event, helper) {
        helper.fireUpdateEvent(component, 'deleteSegmentEvent');
    },

    handleAutocomplete: function(component, event) {
        var selOpt = event.getParam('value');
        var sourceSegment = component.get("v.source");
        sourceSegment.sourceName = selOpt.label;
        sourceSegment.sourceId = selOpt.value;
        component.set("v.source", sourceSegment);
    }
})