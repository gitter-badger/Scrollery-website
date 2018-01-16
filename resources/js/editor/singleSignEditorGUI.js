function SingleSignEditorGUI(singleSignEditor)
{
	this.singleSignEditor = singleSignEditor;

	this.activeSpan = null;
	this.ssePanel = null;
	this.sseTabsPanel = null;
	this.sseCharPages = null;
	this.firstTimeOfSSEDisplay = true;
	this.readingIsModified = [];

	const self = this;

	this.positionJSON2DisplayNames = // TODO redundant with SSE.possiblePositions
	{
		'leftMargin' : 'Left margin',
		'rightMargin': 'Right margin',
		'margin'     : 'Margin',
		'upperMargin': 'Upper margin',
		'lowerMargin': 'Lower margin',
		'aboveLine'  : 'Above line',
		'belowLine'  : 'Below line'
	};

	this.correctionJSON2DisplayNames =
	{
		'overwritten'        : 'Overwritten',
		'horizontal_line'    : 'Strike through',
		'diagonal_left_line' : 'Raising strike through',
		'diagonal_right_line': 'Dropping strike through',
		'dot_below'          : 'Dot below',
		'dot_above'          : 'Dot above',
		'line_below'         : 'Line below',
		'line_above'         : 'Line above',
		'boxed'              : 'Boxed',
		'erased'             : 'Erased'
	};

	this.getPositionName = function(jsonPosition)
	{
		var positionName = this.positionJSON2DisplayNames[jsonPosition];
		if (positionName == null)
		{
			positionName = 'unknown';
		}

		return positionName;
	};

	this.getCorrectionName = function(jsonCorrection)
	{
		var correctionName = this.correctionJSON2DisplayNames[jsonCorrection];
		if (correctionName == null)
		{
			correctionName = 'unknown';
		}

		return correctionName;
	};

	this.createAdditionPlus = function()
	{
		return $('<div></div>')
		.text('+')
		.addClass('bold')
		.addClass('green')
		.addClass('pointerMouse')
	};

	this.createPanel = function()
	{
		this.sseTabsPanel =
		$('<div></div>')
		.attr('id', 'tabsPanel')
		.addClass('oneLine')
		.append
		(
			this.createAdditionPlus()
			.attr('id', 'sseAddReading')
			.addClass('oneLineContent')
			.click(function()
			{
				$('#sseAddReading').fadeOut();
				$('#sseNewReadingInput').val(''); // reset input box
				$('.sseNewReading').fadeIn();
			}),

			$('<input>')
			.attr('id', 'sseNewReadingInput')
			.addClass('sseNewReading')
			.addClass('greyBordered')
			.addClass('oneLineContent')
			.addClass('width14')
			.addClass('largeFontSize')
			.attr('maxlength', 1)
			.hide(),

			$('<button>')
			.attr('id', 'sseNewReadingConfirm')
			.addClass('sseNewReading')
			.addClass('oneLineContent')
			.text('Ok')
			.click(function()
			{
				const newReadingInput = $('#sseNewReadingInput');

				const reading = newReadingInput.val();
				if (reading.length == 1) // accept only single char
				{
					self.singleSignEditor.addReading(reading);
					newReadingInput.text(''); // reset text
				}
			})
			.hide(),

			$('<button>')
			.attr('id', 'sseNewReadingCancel')
			.addClass('sseNewReading')
			.addClass('oneLineContent')
			.text('Cancel')
			.click(function()
			{
				$('.sseNewReading').fadeOut();
				$('#sseAddReading').fadeIn();
			})
			.hide()
		);

		this.sseCharPages =
		$('<div></div>')
		.attr('id', 'sseCharPages')
		.addClass('greyTopBordered')
		.addClass('greyBottomBordered');

		this.ssePanel =
		$('<div></div>')
		.attr('id', 'ssePanel')
		.attr('dir', 'ltr')
		.addClass('asSlimAsPossible')
		.addClass('lightBlueThickBordered')
		.addClass('mediumFontSize')
		.append
		(
			this.sseTabsPanel,

			this.sseCharPages,

			$('<div></div>')
			.addClass('oneLine')
			.append
			(
				$('<button></button>')
				.attr('id', 'finishSSEChangesButton')
				.addClass('oneLineContent')
				.text('Done')
				.click(function()
				{
					self.ssePanel.fadeOut();
					self.activeSpan.removeClass('chosenContent');
				})
			)
		);

		return this.ssePanel;
	};

	this.createPositionDropDown = function(iReading)
	{
		const positionDropDown =
		$('<div></div>')
		.attr('id', 'ssePositionDropDown' + iReading)
		.addClass('greyBordered')
		.addClass('slightlyPadded');

		for (var pos in self.positionJSON2DisplayNames)
		{
			$('<div></div>')
			.attr('iReading', iReading)
			.attr('posJSON', pos)
			.addClass('pointerMouse')
			.text(self.positionJSON2DisplayNames[pos])
			.click(function(event)
			{
				self.singleSignEditor.addPosition
				(
					1 * event.target['iReading'],
					event.target['posJSON']
				);
			})
			.appendTo(positionDropDown);
		}

		return positionDropDown;
	};

	this.createCorrectionDropDown = function(iReading)
	{
		const correctionDropDown =
		$('<div></div>')
		.attr('id', 'sseCorrectionDropDown' + iReading)
		.addClass('greyBordered')
		.addClass('slightlyPadded');

		for (var corr in self.correctionJSON2DisplayNames)
		{
			$('<div></div>')
			.attr('iReading', iReading)
			.attr('corrJSON', corr)
			.addClass('pointerMouse')
			.text(self.correctionJSON2DisplayNames[corr])
			.click(function(event)
			{
				self.singleSignEditor.addCorrection
				(
					1 * event.target['iReading'],
					event.target['corrJSON']
				);
			})
			.appendTo(correctionDropDown);
		}

		return correctionDropDown;
	};

	this.createReadingTab = function(iReading)
	{
		return $('<div></div>')
		.attr('id', 'sseTab' + iReading)
		.addClass('sseTab')
		.addClass('greyBordered')
		.addClass('oneLineContent')
		.addClass('pointerMouse')
		.addClass('largeFontSize')
		.click(function(event)
		{
			const iReading = 1 * event.target.id.replace('sseTab', '');

			self.singleSignEditor.switchReading(iReading);
		});
	};

	this.createCharPage = function(iReading)
	{
		return $('<div></div>')
		.attr('id', 'sseCharPage' + iReading)
		.addClass('sseCharPage')
		.append
		(
			$('<div></div>') // sign char data
			.addClass('greyDashedBottomBordered')
			.append
			(
				$('<div></div>') // char size
				.addClass('oneLine')
				.append
				(
					$('<div></div>')
					.addClass('oneLineContent')
					.text('Char size:'),

					$('<input>')
					.attr('id', 'widthInput' + iReading)
					.attr('placeholder', 'Leave empty for standard size')
					.addClass('oneLineContent')
					.change(function(event)
					{
						var newWidth = event.target.value;
						if (newWidth == '')
						{
							newWidth = 1;
						}
						else if (isNaN(parseFloat(newWidth))
							 &&  isNaN(parseInt(newWidth)))
						{
							console.log('invalid width: ' + newWidth);

							return;
						}

						self.singleSignEditor.changeWidth
						(
							1 * event.target.id.replace('widthInput', ''),
							1 * newWidth
						);
					}),

					$('<button></button>')
					.addClass('someSpaceToTheLeft')
					.addClass('oneLineContent')
					.text('Apply'),

					$('<input type="checkbox">')
					.attr('id', 'mightBeWider' + iReading)
					.addClass('someSpaceToTheLeft')
					.addClass('oneLineContent')
					.change(function()
					{
						self.singleSignEditor.setBinaryAttribute
						(
							'mightBeWider',
							$(this).is(':checked')
						);
					}),

					$('<div></div>')
					.addClass('oneLineContent')
					.text('might be wider')
				),

				$('<div></div>') // position
				.addClass('oneLine')
				.append
				(
					$('<div></div>')
					.addClass('oneLineContent')
					.text('Position:'),

					$('<div></div>')
					.attr('id', 'positionList' + iReading)
					.addClass('oneLineContent'),

					this.createAdditionPlus()
					.attr('id', 'sseAddPosition' + iReading)
					.addClass('someSpaceToTheLeft')
					.addClass('oneLineContent')
					.click(function()
					{
						$('#sseAddPosition' + iReading).fadeOut();
						$('#sseNewPosition' + iReading).fadeIn();
					})
				),

				$('<div></div>') // add position
				.attr('id', 'sseNewPosition' + iReading)
				.addClass('oneLine')
				.append
				(
					this.createPositionDropDown(iReading),

					$('<button>')
					.addClass('oneLineContent')
					.text('Done')
					.click(function()
					{
						$('#sseNewPosition' + iReading).fadeOut();
						$('#sseAddPosition' + iReading).fadeIn();
					})
				)
				.hide()
			),

			$('<div></div>') // sign char reading data
			.append
			(
				$('<div></div>') // reconstructed & retraced
				.addClass('oneLine')
				.append
				(
					$('<input type="checkbox">')
					.attr('id', 'isReconstructed' + iReading)
					.addClass('oneLineContent')
					.change(function()
					{
						self.singleSignEditor.setBinaryAttribute
						(
							'reconstructed',
							$(this).is(':checked')
						);
					}),

					$('<div></div>')
					.text('is reconstructed')
					.addClass('oneLineContent'),

					$('<input type="checkbox">')
					.attr('id', 'isRetraced' + iReading)
					.addClass('someSpaceToTheLeft')
					.addClass('oneLineContent')
					.change(function()
					{
						self.singleSignEditor.setBinaryAttribute
						(
							'retraced',
							$(this).is(':checked')
						);
					}),

					$('<div></div>')
					.addClass('oneLineContent')
					.text('is retraced')
				),

				$('<div></div>') // corrections
				.addClass('oneLine')
				.append
				(
					$('<div></div>')
					.addClass('oneLineContent')
					.text('Corrections:'),

					$('<div></div>')
					.attr('id', 'correctionList' + iReading)
					.addClass('oneLineContent')
					.text('None'),

					this.createAdditionPlus()
					.attr('id', 'addCorrection' + iReading)
					.addClass('someSpaceToTheLeft')
					.addClass('oneLineContent')
					.click(function()
					{
						$('#sseAddCorrection' + iReading).fadeOut();
						$('#sseNewCorrection' + iReading).fadeIn();
					})
				),

				$('<div></div>') // add correction
				.attr('id', 'sseNewCorrection' + iReading)
				.addClass('oneLine')
				.append
				(
					this.createCorrectionDropDown(iReading),

					$('<button>')
					.addClass('oneLineContent')
					.text('Done')
					.click(function()
					{
						$('#sseNewCorrection' + iReading).fadeOut();
						$('#sseAddCorrection' + iReading).fadeIn();
					})
				)
				.hide()
			)
		);
	};

	this.showReading = function(iReading, char)
	{
		var tab = $('#sseTab' + iReading);
		if (tab.length == 0)
		{
			tab =
			this.createReadingTab(iReading) // create new one if necessary
			.insertBefore('#sseAddReading');
		}

		tab
		.text(char)
		.fadeIn();

		this.readingIsModified[iReading] = false;
	};

	this.showNewReading = function(iReading, char)
	{
		this.showReading
		(
			iReading,
			char
		);

		$('.sseNewReading').fadeOut();
		$('#sseAddReading').fadeIn();
	};

	this.showReadingPage = function(iReading, attributes)
	{
		$('.sseCharPage').hide();

		var page = $('#sseCharPage' + iReading);
		if (page.length == 0)
		{
			page = this.createCharPage(iReading);
			this.sseCharPages.append(page);
		}

		$('#widthInput' + iReading).val
		(
			attributes['width'] != null
			? attributes['width']
			: ''
		);
		$('#mightBeWider' + iReading).prop('checked', (attributes['mightBeWider'] == true));

		const posData = attributes['position'];
		const posDisplay = $('#positionList' + iReading);
		if (posData == null)
		{
			posDisplay.text('Regular line');
		}
		else
		{
			posDisplay.text('');

			for (var iPos in posData)
			{
				this.showPosition
				(
					posData[iPos]['position'],
					posDisplay,
					(iPos == 0)
				);
			}
		}

		$('#isReconstructed' + iReading).prop('checked', (attributes['reconstructed'] == true));
		$('#isRetraced'      + iReading).prop('checked', (attributes['retraced']      == true));

		const corrData = attributes['corrected'];
		const corrDisplay = $('#correctionList' + iReading);
		if (corrData == null)
		{
			corrDisplay.text('None');
		}
		else
		{
			corrDisplay.text('');

			for (var iCorr in corrData)
			{
				this.showCorrection
				(
					corrData[iCorr],
					corrDisplay,
					(iCorr == 0)
				);
			}
		}

		page.show();

		// TODO don't fire checkbox etc. events (maybe introduce ignore flag in richTextEditor)
	};

	this.showPosition = function(position, posDisplay, isFirstEntry)
	{
		const displayName = this.getPositionName(position);

		if (isFirstEntry)
		{
			posDisplay.text(displayName);
		}
		else
		{
			posDisplay.text(posDisplay.text() + ' > ' + displayName);
		}
	};

	this.showCorrection = function(correction, corrDisplay, isFirstEntry)
	{
		const displayName = this.getCorrectionName(correction);

		if (isFirstEntry)
		{
			corrDisplay.text(displayName);
		}
		else
		{
			corrDisplay.text(corrDisplay.text() + ' & ' + displayName);
		}
	};

	this.centerSSEAroundChar = function(spanMidX)
	{
		var marginRight = self.ssePanel.parent()[0]['clientWidth'] - spanMidX - self.ssePanel.width() / 2;
		if (marginRight < 0)
		{
			marginRight = 0;
		}

		self.ssePanel
		.css
		({
			'margin-right': marginRight + 'px'
		});
	};

	this.setActiveChar = function(iLine, iSign, readingsData) // TODO mark active char in tabs?
	{
		if (this.activeSpan != null)
		{
			this.activeSpan.removeClass('chosenContent');
		}

		const span = $('#span_' + iLine + '_' + iSign);
		span.addClass('chosenContent');
		this.activeSpan = span;

		const spanMidX = span.position().left + (span.width() / 2);
		this.showSingleSignEditor(iLine, spanMidX);

		$('.sseTab').hide();

		var attributes;
		var displayedSign;
		for (var iReading in readingsData)
		{
			attributes = readingsData[iReading];

			displayedSign = attributes['sign'];
			if (displayedSign == null)
			{
				displayedSign = this.singleSignEditor.signVisualisation.placeholder([attributes['type']]);
			}

			this.showReading
			(
				iReading,
				displayedSign
			);
			this.showReadingPage
			(
				iReading,
				attributes
			);
		}
	};

	this.showCharModification = function(iReading)
	{
		if (!this.readingIsModified[iReading])
		{
			$('#sseTab' + iReading)
			.addClass('modifiedReadingSSE');

			this.readingIsModified[iReading] = true;
		}
	};

	this.showSingleSignEditor = function(iLine, spanMidX)
	{
		this.ssePanel
		.insertAfter('#line' + iLine)
		.fadeIn();

		if (this.firstTimeOfSSEDisplay)
		{
			setTimeout // width of ssePanel is computed too small directly after first time display => move with delay
			(
				function()
				{
					self.centerSSEAroundChar(spanMidX);
				},

				100
			);

			this.firstTimeOfSSEDisplay = false;
		}
		else
		{
			this.centerSSEAroundChar(spanMidX);
		}
	};
}