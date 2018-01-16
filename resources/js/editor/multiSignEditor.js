function MultiSignEditor(richTextEditor)
{
	this.richTextEditor = richTextEditor;
	this.gui = new MultiSignEditorGUI(this);
	this.selectedIndexes = [];
	const self = this;

	this.showMultiSignEditor = function(selectedIndexes, selectedSpans, iLineEnd)
	{
		this.selectedIndexes = selectedIndexes;

		self.gui.showMultiSignEditor
		(
			selectedSpans,
			iLineEnd
		);
	};
}