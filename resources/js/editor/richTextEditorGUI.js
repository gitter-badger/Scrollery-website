function RichTextEditorGUI(richTextEditor)
{
	this.richTextEditor = richTextEditor;
	this.signVisualisation = richTextEditor.signVisualisation;
	const self = this;

	/* line removal & addition */

	$('#richTextLineManager').click(function()
	{
		if (Spider.unlocked == false)
		{
			return;
		}

		const manager = $('#richTextLineManager');

		if (manager.attr('activated') != 1) // null or 0 => activate line management
		{
			$('.removeLineByUser').show();
			$('.addLineByUser').show();
			$('#addLineAtBegin').show();
			$('.lineName').attr('contentEditable', 'true');

			manager.attr('activated', 1);
		}
		else // deactivate line management
		{
			$('.removeLineByUser').hide();
			$('.addLineByUser').hide();
			$('#addLineAtBegin').hide();
			$('.lineName').attr('contentEditable', 'false');

			manager.attr('activated', 0);
		}
	});

	/* listener to text changes by user */

	this.notifyCharSpanChange = function(mutationsList)
	{
		console.log('mutationsList');
		console.log(mutationsList);

		console.log('previous content ' + mutationsList[0].oldValue);
		console.log('updated content ' + mutationsList[0].target.nodeValue);

	};

	this.charSpanChangeObserver = new MutationObserver(this.notifyCharSpanChange);
	this.charSpanChangeObserverConfig =
	{
		// attributes: true,
		// attributeOldValue: true,
		childList: true,
		characterData: true,
		characterDataOldValue: true,
		subtree: true
	};

	/* GUI building */

	this.notifyTextSelection = function()
	{
		const selection = window.getSelection();
		if (selection == null)
		{
			return;
		}
		if (selection.anchorNode == null)
		{
			return;
		}

		console.log('selection');
		console.log(selection);

		var iLineStart = 1 * selection.anchorNode.parentElement.attributes['iline'].value;
		// var iSignStart = 1 * selection.anchorNode.parentElement.attributes['isign'].value;
		var iLineEnd   = 1 * selection.focusNode .parentElement.attributes['iline'].value;
		// var iSignEnd   = 1 * selection.focusNode .parentElement.attributes['isign'].value;

		if (isNaN(iLineStart)
		||  isNaN(iLineEnd))
		{
			return;
		}

		if (iLineStart > iLineEnd)
		{
			iLineEnd = iLineStart;
			//
			// const iLineTemp = iLineStart;
			// const iSignTemp = iSignStart;
			//
			// iLineStart = iLineEnd;
			// iSignStart = iSignEnd;
			//
			// iLineEnd = iLineTemp;
			// iSignEnd = iSignTemp;
		}

		var spansOfLine = [];
		var linePartSpans;
		var iSpan;
		var spanJQ;
		var iSign;
		const selectedIndexes = [];
		const selectedSpans = [];
		for (var iLine = iLineStart; iLine <= iLineEnd; iLine++) // TODO treatment for upper & lower margin
		{
			linePartSpans = $('#leftMargin' + iLine + ' > span');
			for (iSpan = 0; iSpan < linePartSpans.length; iSpan++)
			{
				spansOfLine.push(linePartSpans[iSpan]);
			}

			linePartSpans = $('#regularLinePart' + iLine + ' > span');
			for (iSpan = 0; iSpan < linePartSpans.length; iSpan++) // slightly inefficient, but saves trouble with the object from jQuery
			{
				spansOfLine.push(linePartSpans[iSpan]);
			}

			linePartSpans = $('#rightMargin' + iLine + ' > span');
			for (iSpan = 0; iSpan < linePartSpans.length; iSpan++)
			{
				spansOfLine.push(linePartSpans[iSpan]);
			}

			for (iSpan in spansOfLine)
			{
				if (selection.containsNode(spansOfLine[iSpan], true))
				{
					iSign = 1 * spansOfLine[iSpan].attributes['isign'].value;

					spanJQ =
					$('#span_' + iLine + '_' + iSign)
					.addClass('burlyWoodBackground');

					selectedIndexes.push([iLine, iSign]);
					selectedSpans.push(spanJQ);
				}
			}
		}

		self.richTextEditor.showMultiSignEditor
		(
			selectedIndexes,
			selectedSpans,
			iLineEnd
		);
	};

	this.createLinePart = function(id, inVerticalMargin)
	{
		const linePart =
		$('<td></td>')
		.attr('id', id)
		.attr('contentEditable', 'true')
		.mouseup(self.notifyTextSelection);

		if (!inVerticalMargin)
		{
			linePart
			.addClass('lineSection')
			.addClass('coyBottomBorder');
		}

		return linePart;
	};

	this.createVerticalMargin = function(position)
	{
		return $('<tr></tr>')
		.attr('id', position)
		.append
		(
			$('<td></td>')
			.attr('id', 'lineName_' + position),

			this.createLinePart
			(
				'rightMargin_' + position,
				true
			),

			this.createLinePart
			(
				'regularLinePart_' + position,
				true
			),

			this.createLinePart
			(
				'leftMargin_' + position,
				true
			)
		);
	};

	this.createDummyLineAtBegin = function()
	{
		return $('<tr></tr>')
		.attr('id', 'dummyLine')
		.addClass('richTextLine')
		.append
		(
			$('<td></td>')
			.attr('colspan', 5),

			$('<td></td>')
			.text('+')
			.attr('id', 'addLineAtBegin')
			.attr('title', 'Add a line at begin of fragment')
			.addClass('manageLine')
			.addClass('addLineAtBegin')
			.hide()
			.click(function()
			{
				self.richTextEditor.addLineByUser(0);
			})
		);
	};

	this.createLine = function(lineIndex, lineName)
	{
		return $('<tr></tr>')
		.attr('id', 'line' + lineIndex)
		.addClass('richTextLine')
		.append
		(
			$('<td></td>')
			.attr('id', 'lineName' + lineIndex)
			.addClass('lineName')
			.text(lineName),

			this.createLinePart
			(
				'rightMargin_' + lineIndex,
				false
			),

			this.createLinePart
			(
				'regularLinePart' + lineIndex,
				false
			),

			this.createLinePart
			(
				'leftMargin' + lineIndex,
				false
			),

			$('<td></td>')
			.text('–')
			.attr('id', 'removeLine' + lineIndex)
			.attr('title', 'Remove this line')
			.addClass('manageLine')
			.addClass('removeLineByUser')
			.hide()
			.click(function(event)
			{
				self.richTextEditor.removeLineByUser(event)
			}),

			$('<td></td>')
			.text('+')
			.attr('id', 'addLineAfter' + lineIndex)
			.attr('title', 'Add a line after this one')
			.addClass('manageLine')
			.addClass('addLineByUser')
			.hide()
			.click(function(event)
			{
				self.richTextEditor.addLineByUser(1 * event.target.id.replace('addLineAfter', '') + 1);
			})
		);
	};

	this.createChar = function(iLine, iSign, attributes)
	{
		var span =
		$('<span></span>')
		.attr('id', 'span_' + iLine + '_' + iSign) // only for identification, not for data transport
		.attr('iLine', iLine)
		.attr('iSign', iSign);

		if (attributes['type'] == null) // letter
		{
			span.text(attributes['sign']);

			const w = attributes['width'];
			if (w != null
				&&  w != 1)
			{
				this.signVisualisation.changeWidthOfSpan
				(
					span,
					w
				);
			}
		}
		else // not a letter
		{
			var sign = this.signVisualisation.placeholder([attributes['type']]);

			span.attr('title', 'Sign type: ' + this.signVisualisation.typeName(attributes['type'])); // set tooltip

			if (attributes['width'] == null)
			{
				span.text(sign);
			}
			else
			{
				const widthInteger = Math.round(attributes['width']);
				var markers = sign; // at least 1 sign to present the nonletter, even if it's very narrow

				for (var iMarker = 1; iMarker < widthInteger; iMarker++)
				{
					markers += sign;
				}

				span.text(markers);
			}
		}

		this.signVisualisation.repositionChar
		(
			iLine,
			iSign,
			attributes['position'],
			span,
			true
		);

		if (attributes['isVariant'] == 1)
		{
			span.hide();
		}

		if (attributes['retraced'] == 1)
		{
			span.addClass('retraced');
		}

		if (attributes['readability'] != null)
		{
			if ((attributes['readability']) == 'INCOMPLETE_AND_NOT_CLEAR')
			{
				span.text(span.text() + '\u05af');
			}
			else if ((attributes['readability']) == 'INCOMPLETE_BUT_CLEAR')
			{
				span.text(span.text() + '\u05c4');
			}
		}

		if (attributes['reconstructed'] == 1) // 10
		{
			span.addClass('reconstructed');
		}

		if (attributes['corrected'] != null) // 11
		{
			for (var i in attributes['corrected'])
			{
				span.addClass(attributes['corrected'][i].toLowerCase());
			}
		}

//		if ((attributes['suggested']) != null) // 13.1
//		{
//			span.addClass('suggested');
//		}

//		if ((attributes['comment']) != null) // 13.2
//		{
//			span.attr('title', 'Comment: ' + attributes['comment']);
//		}

		// TODO vocalization (8)

		span.click(function(event) // TODO just one listener for whole frame
		{
			// TODO if same sign clicked again, remove it

			const span = $('#' + event.target.id);
			const iLine = 1 * span.attr('iLine');
			const iSign = 1 * span.attr('iSign');

			self.richTextEditor.setActiveSSEChar
			(
				iLine,
				iSign
			);
		});

		this.charSpanChangeObserver.observe // TODO needs an equivalent at an empty line
		(
			span[0],
			this.charSpanChangeObserverConfig
		);

		return span;
	};

	this.showNewReading = function(iLine, iSign, lineLength, attributes)
	{
		for (var i = lineLength - 1; i >= iSign; i--) // increment sign indexes in DOM
		{
			$('#span_' + iLine + '_' + i)
			.attr('id', 'span_' + iLine + '_' + (i + 1))
			.attr('iSign', i + 1);
		}

		this.createChar
		(
			iLine,
			iSign,
			attributes
		)
		.insertAfter('#span_' + iLine + '_' + (iSign - 1))
		.hide();
	};

	this.switchReading = function(iLine, iSignPrevious, iSignNow)
	{
		$('#span_' + iLine + '_' + iSignPrevious).fadeOut();
		$('#span_' + iLine + '_' + iSignNow).fadeIn();
	};

	this.showRichTextEditor = function(fragmentName, lineNames, text)
	{
		const container = $('#richTextContainer');
		// container.appendTo('#RichTextPanel'); // switch back from single sign editor, if necessary
		// $('#singleSignContainer').appendTo('#hidePanel');

		const buttons = $('#richTextButtons');
		const fragmentNameDiv = $('#fragmentName');

		$('#hidePanel')
		.append
		(
			buttons,
			fragmentNameDiv
		);

		const lowerMargin = this.createVerticalMargin('lowerMargin'); // must be created before normal lines so signs can be added

		container
		.empty()
		.append
		(
			fragmentNameDiv
			.text(fragmentName),

			this.createVerticalMargin('upperMargin'),

			this.createDummyLineAtBegin(),

			lowerMargin
		);

		for (var iLine in text)
		{
			container.append
			(
				this.createLine
				(
					iLine,
					lineNames[iLine]
				)
			);

			const line = text[iLine];
			for (var iSign in line)
			{
				this.createChar
				(
					iLine,
					iSign,
					line[iSign]
				);
			}
		}

		if (text.length > 0) // at least 1 text line
		{
			lowerMargin.insertAfter('#line' + (text.length - 1));
		}
		else
		{
			container.append(lowerMargin);
		}

		container.append(buttons);

		$('#richTextLineManager').attr('activated', 0);
	};
}