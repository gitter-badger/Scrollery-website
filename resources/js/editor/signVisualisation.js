function SignVisualisation(richTextEditor)
{
	this.richTextEditor = richTextEditor;
	const self = this;

	this.fontSize = 20;

	this.signType2Visualisation =
	{
		2: ' ',
		3: '.',
		4: '_',
		5: '#',
		6: '¬',
		7: '¶',
		8: '?'
	};
	this.signType2Name =
	{
		2: 'space',
		3: 'possible vacat',
		4: 'vacat',
		5: 'damage',
		6: 'blank line',
		7: 'paragraph marker',
		8: 'lacuna'
	};

	this.placeholder = function(typeId)
	{
		var placeholder = this.signType2Visualisation[typeId];
		if (placeholder == null)
		{
			placeholder = '?';
		}
		
		return placeholder;
	};

	this.typeName = function(typeId)
	{
		var typeName = this.signType2Name[typeId];
		if (typeName == null)
		{
			typeName = 'unknown';
		}
		
		return typeName;
	};

	this.addLineByUser = function(lineIndex, lineName, newLineAmount) // TODO move to rte gui
	{
		/** increment indexes of lines following the new one */

		for (var iLine = newLineAmount - 1; iLine >= lineIndex; iLine--) // increment the indexes of each following line
		{
			const incrementedIndex = iLine + 1;

			$('#line'            + iLine).attr('id', 'line'            + incrementedIndex);
			$('#lineName'        + iLine).attr('id', 'lineName'        + incrementedIndex);

			$('#rightMargin'     + iLine).attr('id', 'rightMargin'     + incrementedIndex);
			$('#regularLinePart' + iLine).attr('id', 'regularLinePart' + incrementedIndex);
			$('#leftMargin'      + iLine).attr('id', 'leftMargin'      + incrementedIndex);

			$('#removeLine'      + iLine).attr('id', 'removeLine'      + incrementedIndex);
			$('#addLineAfter'    + iLine).attr('id', 'addLineAfter'    + incrementedIndex);
		}

		/** add new line */

		const line = self.createLine
		(
			lineIndex,
			lineName
		);

		if (lineIndex == 0)
		{
			line.insertAfter('#dummyLine');
		}
		else
		{
			line.insertAfter('#line' + (lineIndex - 1));
		}

		$('#removeLine'   + lineIndex).show();
		$('#addLineAfter' + lineIndex).show();
	};

	this.removeLineByUser = function(lineIndex, newLineAmount) // TODO move to rte gui
	{
		$('#line' + lineIndex).remove();

		/** decrement indexes of lines following the removed one */

		for (var iLine = lineIndex + 1; iLine <= newLineAmount; iLine++)
		{
			const decrementedIndex = iLine - 1;

			$('#line'            + iLine).attr('id', 'line'            + decrementedIndex);
			$('#lineName'        + iLine).attr('id', 'lineName'        + decrementedIndex);

			$('#rightMargin'     + iLine).attr('id', 'rightMargin'     + decrementedIndex);
			$('#regularLinePart' + iLine).attr('id', 'regularLinePart' + decrementedIndex);
			$('#leftMargin'      + iLine).attr('id', 'leftMargin'      + decrementedIndex);

			$('#removeLine'      + iLine).attr('id', 'removeLine'      + decrementedIndex);
			$('#addLineAfter'    + iLine).attr('id', 'addLineAfter'    + decrementedIndex);
		}
	};

	this.changeWidthOfSpan = function(span, width)
	{
		span.css
		({
			// 'transform': 'scaleX(' + width + ')'
			'font-size': Math.ceil(this.fontSize * width) + 'px'
		});
	};

	this.changeWidth = function(iLine, iSign, width) // TODO move to rte gui?
	{
		this.changeWidthOfSpan($('#span_' + iLine + '_' + iSign), width);
	};

	this.repositionChar = function(iLine, iSign, positionData, span, addToEndOfLine) // TODO move to rte gui
	{
		var verticalPositionInLine = null;
		var horizontalMargin = null;
		var verticalMargin = null;

		span
		.removeClass('aboveLine')
		.removeClass('belowLine');

		for (var iPos in positionData)
		{
			var pos = positionData[iPos]['position'];

			if (verticalPositionInLine == null)
			{
				if (pos == 'aboveLine'
				||  pos == 'belowLine')
				{
					span.addClass(pos);
					verticalPositionInLine = pos;
				}
			}

			if (horizontalMargin == null)
			{
				if (pos == 'margin')
				{
					pos = 'leftMargin';
				}

				if (pos == 'leftMargin'
				||  pos == 'rightMargin')
				{
					if (verticalMargin == null)
					{
						span.appendTo('#' + pos + iLine);
					}
					else
					{
						span.appendTo('#' + pos + '_' + verticalMargin);
					}

					horizontalMargin = pos;
				}
			}

			if (verticalMargin == null)
			{
				if (pos == 'upperMargin'
				||  pos == 'lowerMargin')
				{
					if (horizontalMargin == null)
					{
						span.appendTo('#regularLinePart_' + pos);
					}
					else
					{
						span.appendTo('#' + horizontalMargin + '_' + pos);
					}

					verticalMargin = pos;
				}
			}
		}

		if (horizontalMargin == null
		&&  verticalMargin == null)
		{
			if (addToEndOfLine != null
			&&  addToEndOfLine == true)
			{
				span.appendTo('#regularLinePart' + iLine);
			}
			else
			{
				const signsOnRegularLine = $('#regularLinePart' + iLine).children();
				var inserted = false;

				for (var i in signsOnRegularLine)
				{
					if (i == 'length') // length follows after actual children
					{
						break;
					}

					if (signsOnRegularLine[i]['attributes']['iSign']['value'] * 1 > iSign)
					{
						span.insertBefore('#' + signsOnRegularLine[i]['id']);
						inserted = true;

						break;
					}
				}

				if (!inserted) // iSign is higher than any in line
				{
					span.appendTo('#regularLinePart' + iLine);
				}
			}
		}
	};

	this.addAttribute = function(iLine, iSign, iReading, attribute, value, positionData, possibleAttributeId)
	{
		const charInLine = $('#span_' + iLine + '_' + iSign);

		if (attribute == 'position')
		{
			this.repositionChar
			(
				iLine,
				iSign,
				positionData,
				charInLine
			);

			var ca = $('#' + possibleAttributeId.replace('possibleAttribute', 'currentAttribute'));
			if (ca.is(':visible')) // this position was already chosen at least once
			{
				const previousText = ca.text();
				const amountIndex = previousText.indexOf('^'); // assumes there is no ^ in position value name

				if (amountIndex == -1) // was chosen exactly once so far
				{
					ca.text(previousText + '^2');
				}
				else // was chosen more than once already
				{
					const newIndex = (1 * previousText.substr(amountIndex + 1)) + 1;

					ca.text(previousText.substr(0, amountIndex + 1) + newIndex);
				}
			}
			else
			{
				ca.show();
			}
		}
		else if (attribute == 'corrected')
		{
			charInLine.addClass(value);
			$('#reading' + iReading).addClass(value);

			$('#' + possibleAttributeId).hide();
			$('#' + possibleAttributeId.replace('possibleAttribute', 'currentAttribute')).show();
		}
		else // any attribute but position or corrected
		{
			charInLine.addClass(attribute);
			$('#reading' + iReading).addClass(attribute);

			$('#' + possibleAttributeId).hide();
			$('#' + possibleAttributeId.replace('possibleAttribute', 'currentAttribute')).show();
		}
	};

	this.showBinaryAttribute = function(iLine, iSign, attributeName, isSet)
	{
		const span = $('#span_' + iLine + '_' + iSign);

		if (isSet)
		{
			span.addClass(attributeName);
		}
		else
		{
			span.removeClass(attributeName);
		}
	};

	// TODO corrections etc.



}