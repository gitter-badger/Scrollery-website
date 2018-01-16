function SingleSignEditor(richTextEditor)
{
	this.richTextEditor = richTextEditor;
	this.textModel = richTextEditor.textModel;
	this.text = richTextEditor.textModel.text;
	this.signVisualisation = richTextEditor.signVisualisation;
	this.gui = new SingleSignEditorGUI(this);
	this.gui.createPanel();
	const self = this;

	this.iLine = -1; // TODO use to avoid hassle with reading indexes from elements
	this.iSign = -1;

	$('#finishSingleSignChangesButton').click(function()
	{
		$('.chosenSignInLine')
		.removeClass('chosenSign')
		.removeClass('chosenSignInLine');
		
		const previewLine = $('#signContext > tr'); // move preview line back
		const index = 1 * previewLine.attr('id').replace('line', '');

		var neighbour = $('#line' + (index + 1));
		if (neighbour.length == 1) // there is a line below the previewed one
		{
			previewLine.insertBefore(neighbour);
		}
		else
        {
            neighbour = $('#line' + (index - 1));

            if (neighbour.length == 1) // there is a line above the previewed one
            {
                previewLine.insertAfter(neighbour);
            }
            else
            {
                previewLine.appendTo('#richTextContainer');
            }
        }

		$('#richTextContainer').appendTo('#RichTextPanel');
		$('#singleSignContainer').appendTo('#hidePanel');
	});
	
	// TODO clean separation between init and reset (in preparation of next sign)
	
	this.possibleAttributes = // TODO change parser output to JSON format
	[
	 	{
	 		'displayName'  : 'might be wider',
	 		'jsonAttribute': 'mightBeWider', // for grouping of modifications
	 		'jsonValue'    : 1
	 	},
	 	{
	 		'displayName'  : 'reconstructed',
	 		'jsonAttribute': 'reconstructed',
	 		'jsonValue'    : 1
	 	},
		{
			'displayName'  : 'retraced',
			'jsonAttribute': 'retraced',
			'jsonValue'    : 1
		},
		{
			'displayName'  : 'position',
			'jsonAttribute': 'position',
			'jsonValue'    : '' // covered by drop down entries (this.possiblePositions)
		},
	 	{
	 		'displayName'  : 'corrected',
	 		'jsonAttribute': 'corrected',
	 		'jsonValue'    : '' // covered by drop down entries (this.possibleCorrections)
	 	}
	];

	this.possiblePositions =
	[
		{
			'displayName'  : 'on left margin',
			'jsonValue'    : 'leftMargin'
		},
		{
			'displayName'  : 'on right margin',
			'jsonValue'    : 'rightMargin'
		},
		{
			'displayName'  : 'margin',
			'jsonValue'    : 'margin'
		},
		{
			'displayName'  : 'on upper margin',
			'jsonValue'    : 'upperMargin'
		},
		{
			'displayName'  : 'on lower margin',
			'jsonValue'    : 'lowerMargin'
		},
		{
			'displayName'  : 'above line',
			'jsonValue'    : 'aboveLine'
		},
		{
			'displayName'  : 'below line',
			'jsonValue'    : 'belowLine'
		}
	];

	this.possibleCorrections =
	[
		{
			'displayName': 'overwritten',
			'jsonValue'  : 'overwritten'
		},
		{
			'displayName': 'strike through',
			'jsonValue'  : 'horizontal_line'
		},
		{
			'displayName': 'raising strike through',
			'jsonValue'  : 'diagonal_left_line'
		},
		{
			'displayName': 'dropping strike through',
			'jsonValue'  : 'diagonal_right_line'
		},
		{
			'displayName': 'dot below',
			'jsonValue'  : 'dot_below'
		},
		{
			'displayName': 'dot above',
			'jsonValue'  : 'dot_above'
		},
		{
			'displayName': 'line below',
			'jsonValue'  : 'line_below'
		},
		{
			'displayName': 'line above',
			'jsonValue'  : 'line_above'
		},
		{
			'displayName': 'boxed',
			'jsonValue'  : 'boxed'
		},
		{
			'displayName': 'erased',
			'jsonValue'  : 'erased'
		}
	];
		
	this.switchReading = function(iReading)
	{
		const iSignReadings = this.textModel.getAlternativeReadings
		(
			this.iLine,
			this.iSign
		);
		const iSignSwitched = iSignReadings[iReading];

		this.richTextEditor.switchReading
		(
			this.iLine,
			this.iSign,
			iSignSwitched
		);

		const readingsData = [];
		for (var iReading in iSignReadings)
		{
			readingsData.push(this.text[this.iLine][iSignReadings[iReading]]);
		}

		this.setActiveChar
		(
			this.iLine,
			iSignSwitched,
			readingsData
		);
	};
	
	this.showCharChange = function(index)
	{
		$('#reading' + index).addClass('modifiedSign'); // TODO remove it once it's back to initial attributes
	};

	this.addReading = function(reading)
	{
		if (Spider.unlocked == false)
		{
			return;
		}

		const mainSignId = this.text[this.iLine][this.iSign]['signId'];

		// const mainSign = $('#reading0'); // assured by fragmentText's getAlternativeReadings()
		// const iLineMain = mainSign.attr('iLine');
		// const iSignMain = 1 * mainSign.attr('iSign'); // change type to integer
		// const mainSignId = this.text[iLineMain][iSignMain]['signId'];

		const alternatives = this.textModel.getAlternativeReadings(this.iLine, this.iSign);
		var maxISign = this.iSign;
		for (var i = 0; i < alternatives.length; i++)
		{
			if (alternatives[i] > maxISign)
			{
				maxISign = alternatives[i];
			}
		}
		const iSign = maxISign + 1;

		// const readings = $('.reading'); // main sign and variants
		// const iReading = readings.length; // 1 for first variant etc.
		//
		// var maxISign = iSignMain;
		// for (var i = 0; i < readings.length; i++)
		// {
		// 	const readingsISign = 1 * $('#reading' + i).attr('iSign');
		// 	if (readingsISign > maxISign)
		// 	{
		// 		maxISign = readingsISign;
		// 	}
		// }
		// const iSign = maxISign + 1;

		// Spider.requestFromServer
		// (
		// 	{
		// 		'request'      : 'addChar',
		// 		'sign'         : reading,
		// 		'mainSignId'   : mainSignId,
		// 		'SCROLLVERSION': Spider.current_version_id
		// 	},
		// 	function(json) // on result
		// 	{
		// 		if (json['error'] != null)
		// 		{
		// 			console.log("json['error'] " + json['error']);
		//
		// 			return;
		// 		}

				/** adapt model */

				self.textModel.addReadingAfter // TODO add position
				(
					{
						'sign': reading,
						'signId': mainSignId,
						'signCharId': 0, // TODO json['signCharId'],
						'isVariant': 1
					},
					self.iLine,
					iSign - 1
				);


				/** adapt visualization */

				self.richTextEditor.showNewReading
				(
					self.iLine,
					iSign
				);

				self.gui.showNewReading
				(
					alternatives.length,
					reading
				);

				// self.showReading
				// (
				// 	iReading,
				// 	iLineMain,
				// 	self.iSign,
				// 	false,
				// 	$('#signReadings')
				// );
				//
				//
				// self.createAttributesDiv(iReading)
				// .append
				// (
				// 	self.createAttributesLists
				// 	(
				// 		iReading,
				// 		{}
				// 	)
				// )
				// .show();
				//
				// self.switchReading(iReading);
				//
				// $('#addReadingDiv').appendTo('#hidePanel');
				// $('#addReadingPseudoButton').appendTo('#signReadings');
				//
				// $('#singleSignContainer').append($('#finishSingleSignChangesButton')); // move Done button to bottom
		// 	}
		// );
	};

	this.changeWidth = function(iReading, width)
	{
		if (Spider.unlocked == false)
		{
			return;
		}
		
		// const reading = $('#reading' + target['id'].replace('widthInput', ''));
		// const iLine = reading.attr('iLine');
		// const iSign = reading.attr('iSign');
		// const signData = this.text[iLine][iSign];

		// Spider.requestFromServer
		// (
		// 	{
		// 		'request'       : 'changeWidth',
		// 		'signCharId'    : signData['signCharId'],
		// 		'width'         : width,
		// 		'SCROLLVERSION' : Spider.current_version_id
		// 	},
		// 	function(json) // on result
		// 	{
		// 		if (json['error'] != null)
		// 		{
		// 			console.log("json['error'] " + json['error']);
		//
		// 			return;
		// 		}

				self.textModel.changeWidth
				(
					self.iLine,
					self.iSign,
					0, // TODO json['signCharId'],
					width
				);

				self.signVisualisation.changeWidth
				(
					self.iLine,
					self.iSign,
					width
				);

				self.gui.showCharModification(iReading);
			// }
		// );
	};
	
	this.addAttribute = function(possibleAttributeId, doSave) // TODO remove DOM dependencies
	{
		if (Spider.unlocked == false
		&&  doSave)
		{
			console.log('Spider.unlocked == false');
			return;
		}
		
		const pa = $('#' + possibleAttributeId);
		if (pa.length == 0)
		{
			console.log('pa.length == 0 at possibleAttributeId = ' + possibleAttributeId);
			return;
		}

		const iReading = pa.attr('iReading');
		const attribute = pa.attr('attribute');
		const value = pa.attr('value');

		if (attribute == 'position'
		&&  value     == '')
		{
			$('#positionDropDown' + iReading).toggle();

			return;
		}
		else if (attribute == 'corrected'
			 &&  value     == '')
		{
			$('#correctionDropDown' + iReading).toggle();

			return;
		}

		const reading = $('#reading' + iReading);
		const iLine = reading.attr('iLine');
		const iSign = reading.attr('iSign');
		var signData = this.text[iLine][iSign];

		if (doSave)
		{
			var signCharReadingDataId = signData['signCharReadingDataId'];
			if (signCharReadingDataId == null)
			{
				signCharReadingDataId = - 1;
			}

			Spider.requestFromServer
			(
				{
					'request'       : 'addAttribute',
					'attributeName' : attribute,
					'attributeValue': value,
					'signId'        : signData['signId'],
					'signCharId'    : signData['signCharId'],
					'signCharReadingDataId': signCharReadingDataId,
					'SCROLLVERSION' : Spider.current_version_id
				},
				function(json) // on result
				{
					if (json['error'] != null)
					{
						console.log("json['error'] " + json['error']);

						return;
					}

					self.textModel.addAttribute
					(
						json,
						iLine,
						iSign,
						attribute,
						value
					);

					self.showCharChange(iReading); // TODO move to visualization, as boolean?

					self.signVisualisation.addAttribute
					(
						iLine,
						iSign,
						iReading,
						attribute,
						value,
						self.text[iLine][iSign]['position'],
						possibleAttributeId
					);
				}
			);
		}
		else // for initial text display don't save anything to the DB
		{
			self.signVisualisation.addAttribute
			(
				iLine,
				iSign,
				iReading,
				attribute,
				value,
				self.text[iLine][iSign]['position'],
				possibleAttributeId
			);
		}
	};
	
	this.removeAttribute = function(currentAttributeId) // TODO remove DOM dependencies
	{
		if (Spider.unlocked == false)
		{
			return;
		}
		
		const ca = $('#' + currentAttributeId);
		if (ca.length == 0)
		{
			return;
		}

		const iReading = ca.attr('iReading');
		const attribute = ca.attr('attribute');
		const value = ca.attr('value');

		const reading = $('#reading' + iReading);
		const iLine = reading.attr('iLine');
		const iSign = reading.attr('iSign');
		const signData = this.text[iLine][iSign];

		var signPositionId = null;
		if (attribute == 'position'
		&&  signData['position'] != null)
		{
			const posData = signData['position'];

			for (var iPos = posData.length - 1; iPos >= 0; iPos--)
			{
				if (posData[iPos]['position'] == value)
				{
					signPositionId = posData[iPos]['signPositionId'];

					break;
				}
			}
		}

		Spider.requestFromServer
		(
			{
				'request'       : 'removeAttribute',
				'attributeName' : attribute,
				'attributeValue': value, // only relevant for corrections
				'signCharId'    : signData['signCharId'],
				'signCharReadingDataId': signData['signCharReadingDataId'], // might be null
				'signPositionId': signPositionId, // might be null
				'SCROLLVERSION' : Spider.current_version_id
			},
			function(json) // on result
			{
				if (json['error'] != null)
				{
					return;
				}

				self.textModel.removeAttribute
				(
					json,
					iLine,
					iSign,
					attribute,
					value
				);

				/** adapt visualization */

				if (attribute == 'position')
				{
					self.signVisualisation.repositionChar
					(
						iLine,
						iSign,
						signData['position'], // TODO must reload from model due to concat?
						$('.chosenSignInLine')
					);

					const previousText = ca.text();
					const amountIndex = previousText.indexOf('^'); // assumes there is no ^ in position value name

					if (amountIndex == -1) // was chosen exactly once so far
					{
						ca.hide();
					}
					else // was chosen more than once already
					{
						const newExponent = (1 * previousText.substr(amountIndex + 1)) - 1;

						if (newExponent == 1) // from ^2 to no exponent
						{
							ca.text(previousText.substr(0, amountIndex));
						}
						else // e.g. from ^3 to ^2
						{
							ca.text(previousText.substr(0, amountIndex + 1) + newExponent);
						}
					}
				}
				else
				{
					if (attribute == 'corrected')
					{
						$('.chosenSign').removeClass(value);
					}
					else
					{
						$('.chosenSign').removeClass(attribute);
					}

					ca.hide();
					$('#' + currentAttributeId.replace('currentAttribute', 'possibleAttribute')).show();
				}

				self.showCharChange(iReading);
			}
		);
	};

	this.addPosition = function(iReading, posJSON)
	{
		// TODO
	};

	this.addCorrection = function(iReading, corrJSON)
	{
		// TODO


	};

	this.showReading = function(iReading, iLine, iSign, isMainSign, signReadings) // TODO remove?
	{
		const signElement =
		$('<span></span>')
		.attr('id', 'reading' + iReading)
		.attr('iLine', iLine)
		.attr('iSign', iSign)
		.addClass('reading')
		.click(function(event)
		{
			self.switchReading(event.target['id'].replace('reading', ''));
		});

		const signData = this.text[iLine][iSign];

		if (signData['type'] == null) // letter
		{
			if (signData['readability'] == null)
			{
				signElement.text(signData['sign']);
			}
			else if (signData['readability'] == 'INCOMPLETE_AND_NOT_CLEAR')
			{
				signElement.text(signData['sign'] + '\u05af');
			}
			else if (signData['readability'] == 'INCOMPLETE_BUT_CLEAR')
			{
				signElement.text(signData['sign'] + '\u05c4');
			}
		}
		else
		{
			signElement.text(this.signVisualisation.placeholder(signData['type']));
		}
		
		if (signData['isVariant'] == null)
		{
			signElement.addClass('chosenSign');
		}
		else
		{
			signElement.addClass('someSpaceToTheLeft');
			signElement.addClass('otherSign');
		}

		const descriptionText =
		(
			isMainSign
			? '(default)'
			: '(alternative)'
		);

		const description =
		$('<span></span>')
		.addClass('signDescription')
		.text(descriptionText);

		signReadings
		.append(signElement)
		.append(description);
	};
	
	this.createAttributesDiv = function(iReading)
	{
		var attributesDiv = $('#attributesDiv' + iReading);
		if (!attributesDiv.length) // div for this sign doesn't exist yet
		{
			attributesDiv =
			$('<div></div>')
			.attr('id', 'attributesDiv' + iReading)
			.addClass('mediumFontSize')
			.addClass('attributesDiv')
			.appendTo('#singleSignContainer');
		}
		else
		{
			attributesDiv.empty();
		}
			
		if (iReading != 0) // show main sign first
		{
			attributesDiv.hide();
		}
		
		return attributesDiv;
	};
	
	this.createAuthorsDiv = function(iReading, signData) // TODO move to GUI, update
	{
		var signAuthorData =
		$('<div></div>')
		.attr('id', 'signAuthorData' + iReading)
		.addClass('someSpaceBelow');
		
//		const ownersDiv = // TODO
//		$('<div></div>')
//		.attr('id', 'authorsAcceptance' + iReading)
//		.addClass('someSpaceBelow')
//		.text('Reading accepted by: You')
//		.appendTo(signAuthorData);
//		
//		const commentsDiv =
//		$('<div></div>')
//		.attr('id', 'authorsComment' + iReading)
//		.appendTo(signAuthorData);
//		
//		$('<span></span>')
//		.text('Your comment: ')
//		.appendTo(commentsDiv);
//				
//		var commentary =
//		(
//			signData['comment'] != null
//			? signData['comment']
//			: ''
//		);
//		
//		$('<input></input>')
//		.attr('id', 'commentInput' + iReading)
//		.val(commentary)
//		.change(function(event)
//		{
//			self.showCharChange(event.target['id'].replace('commentInput', ''));
//		})
//		.appendTo(commentsDiv);
		
		return signAuthorData;
	};

	this.createAttributesLists = function(iReading, signData) // TODO remove?
	{
		const attributeChoiceContainer =
		$('<div></div>')
		.attr('id', 'attributeChoiceDiv' + iReading);
			
		$('<span></span>')
		.text('Sign size: ')
		.appendTo(attributeChoiceContainer);
		
		var width = '';
		if (signData['width'] != null)
		{
			width = signData['width'];
		}
		
		$('<input>')
		.attr('id', 'widthInput' + iReading)
		.attr('placeholder', 'Leave empty for standard size')
		.val(width)
		.change(function(event)
		{
			self.changeWidth(event.target);
		})
		.appendTo(attributeChoiceContainer);

		$('<button>')
		.addClass('someSpaceToTheLeft')
		.text('Apply')
		.appendTo(attributeChoiceContainer);
		
		
		$('<br>')
		.appendTo(attributeChoiceContainer);
		
		$('<br>')
		.appendTo(attributeChoiceContainer);

		const currentAttributesContainer =
		$('<div></div>')
		.addClass('attributesContainer')
		.addClass('someSpaceBelow')
		.appendTo(attributeChoiceContainer);
		
		$('<div></div>')
		.addClass('attributesListHeadline')
		.text('Current attributes')
		.appendTo(currentAttributesContainer);
		
		const currentAttributesDiv =
		$('<div></div>')
		.attr('id', 'currentAttributesDiv' + iReading)
		.addClass('scrollable')
		.addClass('attributesList')
		.appendTo(currentAttributesContainer);
		
		const potentialAttributesContainer =
		$('<div></div>')
		.addClass('attributesContainer')
		.addClass('someSpaceBelow')
		.appendTo(attributeChoiceContainer);
		
		$('<div></div>')
		.addClass('attributesListHeadline')
		.text('Possible attributes')
		.appendTo(potentialAttributesContainer);
		
		const potentialAttributesDiv =
		$('<div></div>')
		.attr('id', 'potentialAttributesDiv' + iReading)
		.addClass('scrollable')
		.addClass('attributesList')
		.appendTo(potentialAttributesContainer);
		
		for (var iPa in this.possibleAttributes)
		{
			const pa = this.possibleAttributes[iPa];

			$('<div></div>')
			.attr('id', 'currentAttribute_' + iPa + '_' + iReading)
			.attr('attribute', pa['jsonAttribute'])
			.attr('value', pa['jsonValue'])
			.attr('iReading', iReading)
			.addClass('attribute')
			.text(pa['displayName'])
			.click(function(event)
			{
				self.removeAttribute(event.target['id']);
			})
			.hide()
			.appendTo(currentAttributesDiv);

			$('<div></div>')
			.attr('id', 'possibleAttribute_' + iPa + '_' + iReading)
			.attr('attribute', pa['jsonAttribute'])
			.attr('value', pa['jsonValue'])
			.attr('iReading', iReading)
			.addClass('attribute')
			.addClass('attribute_' + pa['jsonAttribute'] + '_' + iReading) // allows groups of attributes
			.text(pa['displayName'])
			.click(function(event)
			{
				self.addAttribute(event.target['id'], true);
			})
			.appendTo(potentialAttributesDiv);

			if (pa['jsonAttribute'] == 'position')
			{
				self.createPositionLists(iReading, currentAttributesDiv, potentialAttributesDiv);
			}
			else if (pa['jsonAttribute'] == 'corrected')
			{
				self.createCorrectionLists(iReading, currentAttributesDiv, potentialAttributesDiv);
			}
		}
		
		setTimeout // delayed setting of attributes to make sure divs exist for the browser
		(
			function()
			{
				for (var iPa in self.possibleAttributes)
				{
					const pa = self.possibleAttributes[iPa];
					const attribute = pa['jsonAttribute'];

					if (attribute == 'position'
					||  attribute == 'corrected') // treatment for them see below
					{
						continue;
					}

					if (signData[attribute] == pa['jsonValue']) // according to JSON attribute is set
					{
						self.addAttribute('possibleAttribute_' + iPa + '_' + iReading, false);
					}
				}

				const posData = signData['position'];
				if (posData != null)
				{
					for (var iPos in posData)
					{
						for (var iPp in self.possiblePositions)
						{
							// console.log("posData[iPos]['position'] " + posData[iPos]['position']);
							// console.log("self.possiblePositions[iPa]['jsonValue'] " + self.possiblePositions[iPp]['jsonValue']);
							if (posData[iPos]['position'] == self.possiblePositions[iPp]['jsonValue'])
							{
								self.addAttribute('possibleAttribute_3_' + iPp + '_' + iReading, false); // TODO replace overly static _3_

								break;
							}
						}
					}
				}

				const corrData = signData['corrected'];
				if (corrData != null)
				{
					for (var iCorr in corrData)
					{
						for (var iPc in self.possibleCorrections)
						{
							if (corrData[iCorr] == self.possibleCorrections[iPc]['jsonValue'])
							{
								self.addAttribute('possibleAttribute_4_' + iPc + '_' + iReading, false); // TODO replace overly static _4_

								break;
							}
						}
					}
				}
			},
			
			100
		);
		
		return attributeChoiceContainer;
	};
	
	this.displaySingleSign = function(spanId) // TODO remove?
	{
		const span = $('#' + spanId);
		const iLine  = span.attr('iLine');
		const iSign  = 1 * span.attr('iSign');

		
		/** line context */
		
		const signContext = $('#signContext');
		// .empty(); // TODO necessary when switching fragment while SSE is active, but not when switching sign within preview line
		
		$('.chosenSignInLine')
		.removeClass('chosenSign')
		.removeClass('chosenSignInLine');
		
		const line = $('#line' + iLine);
		if (line.length > 0) // line exists (it always should)
		{
			line.appendTo(signContext);
			
			$('#span_' + iLine + '_' + iSign)
			.addClass('chosenSign')
			.addClass('chosenSignInLine');
		}
		
		const signReadings = $('#signReadings');
		const addReadingPseudoButton = $('#addReadingPseudoButton');
		const finishSingleSignChangesButton = $('#finishSingleSignChangesButton');

		$('#hidePanel')
		.append(signContext)
		.append(signReadings)
		.append(addReadingPseudoButton)
		.append(finishSingleSignChangesButton)
		.append(this.ssePanel); // protect these elements from deletion by empty()

		const container =
		$('#singleSignContainer')
		.empty()
		.append(signContext)
		.append(signReadings);
		// buttons will be re-added later, at the end of their parent elements
		
		const iSignArray = this.textModel.getAlternativeReadings
		(
			iLine,
			iSign
		);

		signReadings.empty(); // reset displayed main sign & variants

		for (var i in iSignArray) // create divs for main sign & variants
		{
			var signData = this.text[iLine][iSignArray[i]];

			this.showReading
			(
				i,
				iLine,
				iSignArray[i],
				(signData['isVariant'] == null),
				signReadings
			);

			var attributesDiv = this.createAttributesDiv(i);

			this.createAuthorsDiv
			(
				i,
				signData
			)
			.appendTo(attributesDiv);

			this.createAttributesLists
			(
				i,
				signData
			)
			.appendTo(attributesDiv);

			if (iSign == iSignArray[i])
			{
				this.switchReading(i);
			}
		}

        addReadingPseudoButton.appendTo(signReadings);
		
//			if (signData['comment'] != null)
//			{
//				authorsDiv.text('Comments: ' + signData['comment']); // TODO support for multiple comments (each user could have one)
////				commentButton.text('Edit comment');
//			}
//			{
////				commentButton.text('Add comment');
//			}
		
		
		container.append(finishSingleSignChangesButton); // add Done button at the bottom
	};

	this.setActiveChar = function(iLine, iSign)
	{
		this.iLine = iLine;
		this.iSign = iSign;

		const iSignReadings = this.textModel.getAlternativeReadings(iLine, iSign);
		const readingsData = [];
		for (var iReading in iSignReadings)
		{
			readingsData.push(this.text[iLine][iSignReadings[iReading]]);
		}

		this.gui.setActiveChar
		(
			iLine,
			iSign,
			readingsData
		);
	};

	this.setBinaryAttribute = function(attributeName, isSet)
	{
		if (Spider.unlocked == false)
		{
			console.log('Spider.unlocked == false');
			return;
		}

		var signData = this.text[this.iLine][this.iSign];

		var attributeValue = 0;
		if (isSet)
		{
			attributeValue = 1;
		}

		var signCharReadingDataId = signData['signCharReadingDataId'];
		if (signCharReadingDataId == null)
		{
			signCharReadingDataId = - 1;
		}

		self.signVisualisation.showBinaryAttribute
		(
			self.iLine,
			self.iSign,
			attributeName,
			isSet
		);


		// Spider.requestFromServer
		// (
		// 	{
		// 		'request'       : 'addAttribute',
		// 		'attributeName' : attributeName,
		// 		'attributeValue': attributeValue,
		// 		'signId'        : signData['signId'],
		// 		'signCharId'    : signData['signCharId'],
		// 		'signCharReadingDataId': signCharReadingDataId,
		// 		'SCROLLVERSION' : Spider.current_version_id
		// 	},
		// 	function(json) // on result
		// 	{
		// 		if (json['error'] != null)
		// 		{
		// 			console.log("json['error'] " + json['error']);
		//
		// 			return;
		// 		}
		//
		// 		self.textModel.addAttribute
		// 		(
		// 			json,
		// 			self.iLine,
		// 			self.iSign,
		// 			attributeName,
		// 			isSet
		// 		);
		//
		// 		self.showCharChange(self.iReading); // TODO move to visualization, as boolean?
		//
		// 		self.signVisualisation.showBinaryAttribute
		// 		(
		// 			self.iLine,
		// 			self.iSign,
		// 			attributeName,
		// 			isSet
		// 		);
		// 	}
		// );
	};
}