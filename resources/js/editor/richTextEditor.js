function RichTextEditor()
{
	this.canonicalFragId = -1;
	this.textModel = new FragmentTextModel();
	this.text = this.textModel.text;

	this.signVisualisation = new SignVisualisation(this);
	this.gui = new RichTextEditorGUI(this);
	
	this.singleSignEditor = new SingleSignEditor(this);
	this.multiSignEditor = new MultiSignEditor(this);
	const self = this; // for usage in event listener


	/* methods */
	
	this.addLineByUser = function(newLineIndex)
	{
		if (Spider.unlocked == false)
		{
			return;
		}

		Spider.requestFromServer
		(
			{
				'request'      : 'createLine',
				'newLineIndex' : newLineIndex,
				'SCROLLVERSION': Spider.current_version_id
			},
			function(json) // on result
			{
				if (json['error'] != null)
				{
					console.log("json['error'] " + json['error']);

					return;
				}

				self.textModel.createLine
				(
					newLineIndex,
					json['lineName']
				);

				self.signVisualisation.addLineByUser
				(
					newLineIndex,
					json['lineName'],
					self.text.length
				);
			}
		);
	};

	this.removeLineByUser = function(event)
	{
		if (Spider.unlocked == false)
		{
			return;
		}

		const removedLineIndex = 1 * event.target.id.replace('removeLine', '');

		console.log('Spider.current_combination ' + Spider.current_combination);


		Spider.requestFromServer
		(
			{
				'request'          : 'removeLine',
				'canonicalFragId'  : this.canonicalFragId,
				'lineIndexToRemove': removedLineIndex,
				'SCROLLVERSION'    : Spider.current_version_id
			},
			function(json) // on result
			{
				if (json['error'] != null)
				{
					console.log("json['error'] " + json['error']);

					return;
				}

				self.textModel.removeLine
				(
					removedLineIndex
				);

				self.signVisualisation.removeLineByUser
				(
					removedLineIndex,
					self.text.length
				);
			}
		);
	};

	this.showRichTextEditor = function(json, canonicalFragId)
	{
		this.textModel.setFragment(json);
		this.canonicalFragId = canonicalFragId;

		this.gui.showRichTextEditor
		(
			this.textModel['fragmentName'],
			this.textModel['lineNames'],
			this.text
		);
	};

	this.showNewReading = function(iLine, iSign)
	{
		this.gui.showNewReading
		(
			iLine,
			iSign,
			this.text[iLine].length,
			this.text[iLine][iSign]
		);
	};

	this.setActiveSSEChar = function(iLine, iSign)
	{
		this.singleSignEditor.setActiveChar
		(
			iLine,
			iSign
		);
	};

	this.switchReading = function(iLine, iSignPrevious, iSignNow)
	{
		this.gui.switchReading
		(
			iLine,
			iSignPrevious,
			iSignNow
		);
	};

	this.showMultiSignEditor = function(selectedIndexes, selectedSpans, iLineEnd)
	{
		self.multiSignEditor.showMultiSignEditor
		(
			selectedIndexes,
			selectedSpans,
			iLineEnd
		);
	};

	Spider.register_object
	([
		{
			type: 'load_text',
			execute_function: function(data)
			{
				self.showRichTextEditor
				(
					data.data,
					data.canonicalFragId
				);
			},
			name: "RichTextEditor"
		}
	]);
}

// TODO add context menus based on example of fragmentPuzzle.js?