function MultiSignEditorGUI(multiSignEditor)
{
	this.multiSignEditor = multiSignEditor;
	this.msePanel = null;
	this.firstTimeOfMSEDisplay = true;
	this.selectedSpans = [];

	const self = this;

	this.toggleBinaryAttribute = function(attributeName) // TODO call backend
	{
		var doAllSpansHaveAttribute = true;
		for (var iSpan in this.selectedSpans)
		{
			if (!this.selectedSpans[iSpan].hasClass(attributeName))
			{
				doAllSpansHaveAttribute = false;

				break;
			}
		}

		if (doAllSpansHaveAttribute)
		{
			for (var iSpan in this.selectedSpans)
			{
				this.selectedSpans[iSpan].removeClass(attributeName);
			}
		}
		else
		{
			for (var iSpan in this.selectedSpans)
			{
				this.selectedSpans[iSpan].addClass(attributeName);
			}
		}
	};

	this.createBinaryAttributeToggle = function(attributeName)
	{
		return $('<div></div>')
		.attr('attributeName', attributeName)
		.attr('title', 'Toggle ' + attributeName + ' on selection')
		.addClass('oneLineContent')
		.addClass('greyBordered')
		.addClass('burlyWoodBackground')
		.addClass('pointerMouse')
		.addClass(attributeName)
		.text('א')
		.click(function()
		{
			self.toggleBinaryAttribute(attributeName);
		});
	};

	this.createPanel = function()
	{
		this.msePanel =
		$('<div></div>')
		.attr('id', 'msePanel')
		.attr('dir', 'ltr')
		.addClass('bordered')
		.addClass('oneLine')
		.addClass('largeFontSize')
		.append
		(
			this.createBinaryAttributeToggle('reconstructed'),

			this.createBinaryAttributeToggle('retraced'),

			$('<button>')
			.addClass('oneLineContent')
			.text('Done')
			.click(function()
			{
				self.msePanel.fadeOut();
				self.removePreviousSelectionMarkers();
			})
		);
	};

	this.removePreviousSelectionMarkers = function()
	{
		for (var iSpan in this.selectedSpans)
		{
			this.selectedSpans[iSpan].removeClass('burlyWoodBackground');
		}
	};

	this.centerMSEAroundEndSpan = function()
	{
		var spansMidX = 0;
		for (var iSpan in this.selectedSpans)
		{
			spansMidX += this.selectedSpans[iSpan].position().left + this.selectedSpans[iSpan].width() / 2;
		}
		spansMidX /= this.selectedSpans.length;

		var marginRight = self.msePanel.parent()[0]['clientWidth'] - spansMidX - self.msePanel.width() / 2;
		if (marginRight < 0)
		{
			marginRight = 0;
		}

		self.msePanel
		.css
		({
			'margin-right': marginRight + 'px'
		});
	};

	this.showMultiSignEditor = function(selectedSpans, iLineEnd)
	{
		this.msePanel
		.insertBefore('#line' + iLineEnd)
		.fadeIn();

		this.removePreviousSelectionMarkers();

		this.selectedSpans = selectedSpans;

		if (this.firstTimeOfMSEDisplay)
		{
			setTimeout // width of ssePanel is computed too small directly after first time display => move with delay
			(
				self.centerMSEAroundEndSpan(),

				500
			);

			this.firstTimeOfMSEDisplay = false;
		}
		else
		{
			this.centerMSEAroundEndSpan();
		}
	};

	this.createPanel();
}