#! /usr/bin/perl

use strict;
use warnings;

use feature qw(say);
use Data::Dumper;

use lib qw(/home/perl_libs);
use SQE_CGI;
use SQE_DBI;
use SQE_API::Queries;

use CGI;
use JSON;


# HELPER FUNCTIONS

sub query_SQE
{
	my $cgi = shift;
	my $result_type = shift;
	my $query_text = shift;
	my @query_parameters = @_; # might be empty
	
	my $dbh = $cgi->dbh;
	
	my $query = $dbh->prepare_sqe($query_text);
	my $i_param = 1;
	foreach my $param (@query_parameters)
	{
	    $query->bind_param($i_param, $param);
	    $i_param++;
    }
	$query->execute();
	
	if ($result_type eq 'first_value')
	{
		my $result = ($query->fetchrow_array())[0];
		$query->finish();
		return $result; 
	}
	elsif ($result_type eq 'first_array')
	{
		my @result = $query->fetchrow_array();
		$query->finish();
		return @result;
	}
	elsif ($result_type eq 'all')
	{
		my @result;
		while (my @row = $query->fetchrow_array())
		{
			push @result, @row;
		}
		$query->finish();
		return @result;
	}
	elsif ($result_type eq 'none')
	{
		$query->finish();
	}
	else
	{
		return $query;		
	}
}

sub lastInsertedId_SQE
{
	my $cgi = shift;
	
	return query_SQE
	(
		$cgi,
		'first_value',
	
		'SELECT LAST_INSERT_ID()'
	);
}

sub _set_scrollversion
{
	my $cgi = shift;

	my $scroll_version_id = $cgi->param('SCROLLVERSION');
	if (!defined $scroll_version_id)
	{
		$scroll_version_id = 1;
	}
	$cgi->dbh->set_scrollversion($scroll_version_id);
}

sub _get_fragment_id_from_canonical_reference_id
{
	my $cgi = shift;

	return query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT col_id FROM scroll_to_col
		WHERE scroll_to_col_id =
		(
			SELECT column_of_scroll_id FROM discrete_canonical_references
			WHERE discrete_canonical_reference_id = ?
		)
MYSQL

		scalar $cgi->param('canonicalFragId')
	);
}

sub _get_sign_stream_and_start_sign
{
	my $dbh = shift;
	my $fragment_id = shift;

	#	my $get_start_query = $dbh->prepare_sqe(SQE_API::Queries::GET_LINE_BREAK,$line_index_to_remove);
	my $get_start_query = $dbh->prepare_sqe(SQE_API::Queries::GET_FRAGMENT_BREAK);

	my $sign_stream = $dbh->create_sign_stream_for_fragment_id($fragment_id);
	#	$cgi->print('$sign_stream'.Dumper($sign_stream));
	#	$get_start_query->execute($fragment_id, 'LINE_START');
	#	my $start_sign_id = ($get_start_query->fetchrow_array)[0];
	#	$cgi->print('{"$start_sign_id":'.$start_sign_id.'}');
	#	return;
	$get_start_query->execute($fragment_id, 'COLUMN_START');
	my $start_sign_id = ($get_start_query->fetchrow_array)[0];
	$sign_stream->set_start_id($start_sign_id);

	return ($sign_stream, $start_sign_id);
}


# FUNCTIONS RELATED TO CLIENT REQUESTS

# returns session & user id; most work is covered by SQE_CGI.pm 
sub login
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	
	$cgi->print('{"SESSION_ID":"'.$cgi->session_id.'", "USER_ID":'.$dbh->user_id.'}');
}

sub logout
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my $user_name = $cgi->param('user');
	my $user_id = userId($user_name);
	
	# end their session if one is running
	query
	(
		'UPDATE user_sessions '
		.'SET session_end = NOW()'
		.', current = false '
		.'WHERE user_id='.$user_id
		.' AND current = true',
		$dbh
	);
		
	print 1;
}

sub getManifest
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my $url = $cgi->param('url');
	my $sou = get($url) or die "cannot retrieve code\n";
	
	print $sou;
}

sub load_fragment_text
{
	my $cgi = shift;

	my $dbh = $cgi->dbh;
	my $scroll_version = $cgi->param('SCROLLVERSION');
	if (defined $scroll_version)
	{
		$dbh->set_scrollversion($scroll_version);
	}
	
	
	# get scroll & fragment data
	
	my ($scroll_id, $col_of_scroll_id) = query_SQE
	(
		$cgi,
		'first_array',
		
		<<'MYSQL',
		SELECT discrete_canonical_name_id, column_of_scroll_id FROM discrete_canonical_references
		WHERE discrete_canonical_reference_id = ?
MYSQL

		scalar $cgi->param('discreteCanonicalReferenceId')
	);
	my $fragment_id = query_SQE
	(
		$cgi,
		'first_value',
		
		<<'MYSQL',
		SELECT col_id FROM scroll_to_col
		WHERE scroll_to_col_id = ?
MYSQL

		$col_of_scroll_id
	);
	
	my @scroll_and_fragment_names = query_SQE
	(
		$cgi,
		'first_array',

		<<'MYSQL',
		SELECT scroll_data.name, col_data.name FROM scroll_data, col_data
		WHERE col_data.col_id = ?
		AND scroll_data.scroll_id =
		(
			SELECT scroll_id FROM scroll_to_col
			WHERE col_id = ?
		)
MYSQL

		$fragment_id,
		$fragment_id
	);
	my $fragment_name = $scroll_and_fragment_names[0].' '.$scroll_and_fragment_names[1];
	
	
	# get sign stream
	
	my $line_ids_query = $dbh->prepare_sqe # TODO sort order
	(
		<<'MYSQL',
		SELECT line_id FROM col_to_line
		WHERE col_id = ?
MYSQL
	);
	$line_ids_query->execute($fragment_id);
	
	my $line_name_query = $dbh->prepare_sqe
	(
		<<'MYSQL',
		SELECT name FROM line_data
		WHERE line_id = ?
MYSQL
	);
	
#	my $get_start_query = $dbh->prepare_sqe(SQE_API::Queries::GET_LINE_BREAK);
	my $get_start_query = $dbh->prepare_sqe(SQE_API::Queries::GET_FRAGMENT_BREAK);

	my $sign_stream = $dbh->create_sign_stream_for_fragment_id($fragment_id);
#	$cgi->print('$sign_stream'.Dumper($sign_stream));
	$get_start_query->execute($fragment_id, 'COLUMN_START');
	my $start_sign_id = ($get_start_query->fetchrow_array)[0];
	$sign_stream->set_start_id($start_sign_id);
	
	my $line_end = 1;
	
	my $line_id = ($line_ids_query->fetchrow_array)[0];
	$line_name_query->execute($line_id);
	my $line_name = ($line_name_query->fetchrow_array)[0];
	my $json_string = '{"fragmentName":"'.$fragment_name.'","lines":[{"lineName":"'.$line_name.'","signs":[';
	
	my $first_sign_of_line = 1;
	
	my $current_sign_scalar; # as scalar first for simple check whether existant
	my $sign_id;
	while ($current_sign_scalar = $sign_stream->next_sign())
	{
		my @sign = @{ $current_sign_scalar };
		
		if ($sign[3] == 9) # line end / line start (might be column end / scroll end also, but not relevant here) 
		{
			if ($line_end)
			{
				$json_string .= ']}';
			}
			else
			{
				$line_id = ($line_ids_query->fetchrow_array)[0];
				$line_name_query->execute($line_id);
				$line_name = ($line_name_query->fetchrow_array)[0];
				$json_string .= ',{"lineName":"'.$line_name.'","signs":[';
				
				$first_sign_of_line = 1;
			}
			
			$line_end = !$line_end;
			
			next;
		}
		
		if (!$first_sign_of_line)
		{
			$json_string .= ',';
		}
		$first_sign_of_line = 0;
		
		
		# collect sign attributes
		
		$json_string .= '{"signId":'.$sign[1];
		$sign_id = $sign[1];
		
		if ($sign[3] == 1) { $json_string .= ',"sign":"'.$sign[2].'"'; } # letter
		else               { $json_string .= ',"type":"'.$sign[3].'"'; }
		
		if ($sign[13] != 0) { $json_string .= ',"signCharId":'.$sign[13]; }
		if ($sign[11] == 1) { $json_string .= ',"isVariant":1'; }
		if ($sign[ 5] != 1) { $json_string .= ',"width":"'.$sign[5].'"'; }
		if ($sign[ 6] == 1) { $json_string .= ',"mightBeWider":1'; }
		
		if (defined $sign[12]) # sign_char_reading_data entry exists, but might be off for this scroll_version
		{
			$json_string .= ',"signCharReadingDataId":'.$sign[12];
			
			if (defined $sign[ 7] && !($sign[ 7] eq 'COMPLETE')) { $json_string .= ',"readability":"'.$sign[7].'"'; }
			if (defined $sign[ 8] &&   $sign[ 8] == 1)           { $json_string .= ',"retraced":1'; }
			if (defined $sign[ 9] &&   $sign[ 9] == 1)           { $json_string .= ',"reconstructed":1'; }
			if (defined $sign[10] && !($sign[10] eq ''))         { $json_string .= ',"corrected":"'.lc($sign[10]).'"'; }
		}
		
		my @sign_relative_positions = query_SQE 
		(
			$cgi,
			'all',
			
			<<'MYSQL',
			SELECT sign_relative_position_id, type, level FROM sign_relative_position
			WHERE sign_id = ?
			AND sign_relative_position_id IN
			(
				SELECT sign_relative_position_id FROM sign_relative_position_owner
				WHERE scroll_version_id = ?
			)
			ORDER BY level
MYSQL

			$sign[1],
			$scroll_version
		);
		if (scalar @sign_relative_positions > 0)
		{
			$json_string .= ',"position":[';
			
			for (my $pos_i = 0; $pos_i < scalar @sign_relative_positions; $pos_i += 3)
			{
				if ($pos_i) # not the lowest level
				{
					$json_string .= ',';
				}
				
				$json_string .= '{"signPositionId":'.$sign_relative_positions[$pos_i];
				
				my $pos = $sign_relative_positions[$pos_i + 1];
				if    ($pos eq 'ABOVE_LINE')   { $json_string .= ',"position":"aboveLine"'; }
				elsif ($pos eq 'BELOW_LINE')   { $json_string .= ',"position":"belowLine"'; }
				elsif ($pos eq 'LEFT_MARGIN')  { $json_string .= ',"position":"leftMargin"'; }
				elsif ($pos eq 'RIGHT_MARGIN') { $json_string .= ',"position":"rightMargin"'; }
				elsif ($pos eq 'MARGIN')       { $json_string .= ',"position":"margin"'; }
				elsif ($pos eq 'UPPER_MARGIN') { $json_string .= ',"position":"upperMargin"'; }
				elsif ($pos eq 'LOWER_MARGIN') { $json_string .= ',"position":"lowerMargin"'; }
				
				$json_string .= ',"level":'.$sign_relative_positions[$pos_i + 2].'}';
			}
			
			$json_string .= ']';
		}
		
		$json_string .= '}'; # close sign
	}
	
	$line_ids_query->finish;
	$line_name_query->finish;
	$get_start_query->finish;
	
	$json_string .= ']}'; # close array of lines and entire json
	$cgi->print($json_string);
}

sub add_char
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	
	my $scroll_version_id = $cgi->param('SCROLLVERSION');
	if (!defined $scroll_version_id)
	{
		$scroll_version_id = 1;
	}
	$dbh->set_scrollversion($scroll_version_id);

	my @result = $dbh->add_value
	(
		'sign_char',
		0,
		'sign_id',
		scalar $cgi->param('mainSignId'),
		'is_variant',
		1,
		'sign',
		scalar $cgi->param('sign')
	);

	if (defined $result[0])
	{
		$cgi->print('{"signCharId":'.$result[0].'}');
	}
	elsif (defined $result[1])
	{
		$cgi->print('{"error":"'.${$result[1]}[1].'"}');
	}
}

sub change_width
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	
	my $scroll_version_id = $cgi->param('SCROLLVERSION');
	if (!defined $scroll_version_id)
	{
		$scroll_version_id = 1;
	}
	$dbh->set_scrollversion($scroll_version_id);
	
	my @result = $dbh->change_value
	(
		'sign_char',
		scalar $cgi->param('signCharId'),
		'width',
		scalar $cgi->param('width')
	);
	
	if (defined $result[0])
	{
		$cgi->print('{"signCharId":'.$result[0].'}');
	}
	else
	{
		$cgi->print('{"error":"'.${$result[1]}[1].'"}');
	}
}

sub _add_position
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	my $scroll_version_id = shift;
	my $attribute_value = shift;

	my $json = '{';

	my $type;
	if    ($attribute_value eq 'leftMargin')  { $type = 'LEFT_MARGIN'; }
	elsif ($attribute_value eq 'rightMargin') { $type = 'RIGHT_MARGIN'; }
	elsif ($attribute_value eq 'aboveLine')   { $type = 'ABOVE_LINE'; }
	elsif ($attribute_value eq 'belowLine')   { $type = 'BELOW_LINE'; }
	elsif ($attribute_value eq 'margin')      { $type = 'MARGIN'; }
	elsif ($attribute_value eq 'upperMargin') { $type = 'UPPER_MARGIN'; }
	elsif ($attribute_value eq 'lowerMargin') { $type = 'LOWER_MARGIN'; }

	my $sign_id = $cgi->param('signId');

	# determine new level

	my $level = 1;
	my @previous_max_level = query_SQE # TODO can result in multiple positions with same level, if added A, removed A, added B, ...
	(
		$cgi,
		'all',

		<<'MYSQL',
		SELECT max(level) FROM sign_relative_position
		JOIN sign_relative_position_owner
		ON (sign_relative_position.sign_relative_position_id = sign_relative_position_owner.sign_relative_position_id)
		WHERE sign_id = ?
	  	AND scroll_version_id = _scrollversion_
MYSQL

		$sign_id
	);
	if (scalar @previous_max_level > 0)
	{
		$level = $previous_max_level[0] + 1;
	}
	$json .= '"level":'.$level;

	my @result = $dbh->add_value
	(
		'sign_relative_position',
		0,
		'sign_id',
		$sign_id,
		'type',
		$type,
		'level',
		$level
	);

	if (defined $result[0])
	{
		$json .= ',"signPositionId":'.$result[0];
	}
	elsif (defined $result[1])
	{
		$json .= ',"error":"'.${$result[1]}[1].'"';
	}

	$cgi->print($json.'}');
}

sub _add_correction
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	my $reading_data_id = scalar $cgi->param('signCharReadingDataId');
	my $correction = uc(shift);

	my @result;
	if ($reading_data_id != -1)
	{
		my $existing_corrections = query_SQE
		(
			$cgi,
			'first_value',

			<<'MYSQL',
			SELECT correction FROM sign_char_reading_data
			WHERE sign_char_reading_data_id = ?
MYSQL

			$reading_data_id
		);

		if (defined $existing_corrections
		&&	length $existing_corrections > 0)
		{
			$correction = $existing_corrections.','.$correction;
		}

		@result = $dbh->change_value
		(
			'sign_char_reading_data',
			$reading_data_id,
			'correction',
			$correction
		);
	}
	else
	{
		@result = $dbh->add_value
		(
			'sign_char_reading_data',
			0,
			'sign_char_id',
			scalar $cgi->param('signCharId'),
			'correction',
			$correction
		);
	}

	if (defined $result[0])
	{
		$cgi->print('{"signCharReadingDataId":'.$result[0].'}');
	}
	elsif (defined $result[1])
	{
		$cgi->print('{"error":"'.${$result[1]}[1].'"}');
	}
}

sub add_attribute
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	
	my $scroll_version_id = $cgi->param('SCROLLVERSION');
	if (!defined $scroll_version_id)
	{
		$scroll_version_id = 1;
	}
	$dbh->set_scrollversion($scroll_version_id);

	my $attribute_name = $cgi->param('attributeName');
	my $attribute_value = $cgi->param('attributeValue');

	my @result;
	if ($attribute_name eq 'mightBeWider')
	{
		@result = $dbh->change_value
		(
			'sign_char',
			scalar $cgi->param('signCharId'),
			'might_be_wider',
			$attribute_value
		);
		
		if (defined $result[0])
		{
			$cgi->print('{"signCharId":'.$result[0].'}');
		}
	}
	elsif ($attribute_name eq 'position')
	{
		_add_position
		(
			$cgi,
			$scroll_version_id,
			$attribute_value
		);
	}
	elsif ($attribute_name eq 'corrected')
	{
		_add_correction
		(
			$cgi,
			$attribute_value
		);
	}
	else # reconstructed / retraced
	{
		my $name = 'is_'.$attribute_name;
		my $value = 1;

		my $id = $cgi->param('signCharReadingDataId');
		if ($id != -1)
		{
			@result = $dbh->change_value
			(
				'sign_char_reading_data',
				scalar $cgi->param('signCharReadingDataId'),
				$name,
				$value
			);
		}
		else # no sign_char_reading_data entry yet
		{
			@result = $dbh->add_value
			(
				'sign_char_reading_data',
				0,
				'sign_char_id',
				scalar $cgi->param('signCharId'),
				$name,
				$value
			);
		}
		
		if (defined $result[0])
		{
			$cgi->print('{"signCharReadingDataId":'.$result[0].'}');
		}
	}

	if (defined $result[1])
	{
		$cgi->print('{"error":"'.${$result[1]}[1].'"}');
	}
}

sub _remove_correction
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	my $reading_data_id = scalar $cgi->param('signCharReadingDataId');

	my $existing_corrections = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT correction FROM sign_char_reading_data
		WHERE sign_char_reading_data_id = ?
MYSQL

		$reading_data_id
	);

	if (!defined $existing_corrections
	||  length $existing_corrections == 0)
	{
		$cgi->print('{"error":"Could not remove correction"}');
	}
	else
	{
		my $correction_to_remove = uc($cgi->param('attributeValue'));
		my $correction_index = index($existing_corrections, $correction_to_remove);

		if ($correction_index == -1) # not found (shouldn't happen)
		{
			$cgi->print('{"error":"Could not remove correction"}');
		}
		else
		{
			my $new_correction_string;

			if ($correction_index > 0)
			{
				$new_correction_string =
				substr($existing_corrections, 0, $correction_index - 1) # before entry to be removed and its leading comma
				.substr($existing_corrections, $correction_index + length $correction_to_remove); # after entry to be removed
			}
			else # entry to be removed is located at begin
			{
				if ($correction_to_remove eq $existing_corrections)
				{
					$new_correction_string = '';
				}
				else # remove entry and trailing comma
				{
					$new_correction_string = substr($existing_corrections, length($correction_to_remove) + 1);
				}
			}

			my @result = $dbh->change_value
			(
				'sign_char_reading_data',
				$reading_data_id,
				'correction',
				$new_correction_string
			);

			if (defined $result[0])
			{
				$cgi->print('{"signCharReadingDataId":'.$result[0].'}');
			}
			elsif (defined $result[1])
			{
				$cgi->print('{"error":"'.${$result[1]}[1].'"}');
			}
		}
	}
}

sub remove_attribute
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	
	my $scroll_version_id = $cgi->param('SCROLLVERSION');
	if (!defined $scroll_version_id)
	{
		$scroll_version_id = 1;
	}
	$dbh->set_scrollversion($scroll_version_id);
	
	my $attribute_name = $cgi->param('attributeName');

	my @result;
	if ($attribute_name eq 'mightBeWider')
	{
		@result = $dbh->change_value
		(
			'sign_char',
			scalar $cgi->param('signCharId'),
			'might_be_wider',
			0
		);
		
		if (defined $result[0])
		{
			$cgi->print('{"signCharId":'.$result[0].'}');
		}
	}
	elsif ($attribute_name eq 'position')
	{
		@result = $dbh->remove_entry
		(
			'sign_relative_position',
			scalar $cgi->param('signPositionId')
		);
		
		if (!defined $result[1])
		{
			$cgi->print('{"signPositionId":-1}');
		}
	}
	elsif ($attribute_name eq 'corrected')
	{
		_remove_correction($cgi);
	}
	else # reconstructed / retraced
	{
		@result = $dbh->change_value
		(
			'sign_char_reading_data',
			scalar $cgi->param('signCharReadingDataId'),
			'is_'.$attribute_name,
			0
		);
		
		if (defined $result[0])
		{
			$cgi->print('{"signCharReadingDataId":'.$result[0].'}');
		}
	}
	
	if (defined $result[1])
	{
		$cgi->print('{"error":"'.${$result[1]}[1].'"}');
	}
}

sub add_line
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	my $line_index_to_insert = $cgi->param('newLineIndex');

	my $scroll_version_id = $cgi->param('SCROLLVERSION');
	if (!defined $scroll_version_id)
	{
		$scroll_version_id = 1;
	}
	$dbh->set_scrollversion($scroll_version_id);

	my ($sign_stream, $start_sign_id) = _get_sign_stream_and_start_sign
	(
		$dbh,
		_get_fragment_id_from_canonical_reference_id($cgi)
	);

	# search for position where to insert

	my $sign_id_before_line;
	my $stream_id_before_line;
	my $sign_char_id_before_line;

	my $start_break_type;
	if ($line_index_to_insert == 0)
	{


	}
	else # search through stream for begin of nth line
	{
		my $sign_scalar; # as scalar first for simple check whether existent
		my @sign;

		my $is_line_start = 0;
		my $line_counter = 0;
		my $line_start_sign_char_id;

		while ($sign_scalar = $sign_stream->next_sign())
		{
			@sign = @{ $sign_scalar };
			if ($sign[3] == 9) # line end or line start
			{
				if ($is_line_start)
				{
					$line_counter++;

					if ($line_counter == $line_index_to_insert)
					{
						$line_start_sign_char_id = $sign[13];

						last;
					}
				}

				$is_line_start = !$is_line_start;
			}

			$sign_id_before_line = $sign[1];
			$sign_char_id_before_line = $sign[13];
		}

		if (!defined $line_start_sign_char_id)
		{
			$cgi->print('{"error":"could not find line start"}');
			return;
		}

		$stream_id_before_line = query_SQE
		(
			$cgi,
			'first_value',

			<<'MYSQL',
			SELECT position_in_stream_id FROM position_in_stream
			JOIN position_in_stream_owner USING (position_in_stream_id)
			WHERE sign_id = ?
			AND position_in_stream_owner.scroll_version_id = _scrollversion_
MYSQL

			$sign_id_before_line
		);

		$start_break_type = query_SQE
		(
			$cgi,
			'first_value',

			<<'MYSQL',
			SELECT break_type FROM sign_char
			JOIN sign_char_owner USING (sign_char_id)
			WHERE sign_char_id = ?
			AND sign_char_owner.scroll_version_id = _scrollversion_
MYSQL

			$line_start_sign_char_id
		);
	}

#	$cgi->print('{"data":['
#	.$stream_id_before_line.','
#	.$stream_id_after_line.','
#	.$sign_char_id_before_line.','
#	.$sign_char_id_after_line.','
#	.$start_break_type.','
#	.$end_break_type
#	.']}');

	return;


	# TODO
	# insert break_type of new line start of saved start combination
	# change break_type of existing line start to LS
	# same with end
	# change next_sign entries: before new line -> new line start -> new line end -> after new line









#	const previousName = $('#lineName' + lineIndex).text(); // name of previous line
#
#				var name = '?';
#	if (previousName * 1 == previousName) // name is number
#			{
#				name = (previousName * 1) + 1; // increment the number (might collide with following line, scholar must handle that)
#			}
#	else
#	{
#		const lastCharCode = previousName.substr(previousName.length() - 1).charCodeAt(0);
#
#		if ((lastCharCode > 96 && lastCharCode < 123)
#			||  (lastCharCode > 64 && lastCharCode <  91)) // previous name ends with a to y OR A .. Y
#			{
#				name = previousName.substr(0, previousName.length() - 1) + String.fromCharCode(lastCharCode + 1);
#			}
#		}


}

sub remove_line
{
	my $cgi = shift;
	my $dbh = $cgi->dbh;
	my $line_index_to_remove = $cgi->param('lineIndexToRemove');

	_set_scrollversion($cgi);

	my ($sign_stream, $start_sign_id) = _get_sign_stream_and_start_sign
	(
		$dbh,
		_get_fragment_id_from_canonical_reference_id($cgi)
	);

	my $sign_scalar;
	my @sign;

	if ($line_index_to_remove == 0)
	{
		my $start_break_type = query_SQE
		(
			$cgi,
			'first_value',

			<<'MYSQL',
			SELECT break_type FROM sign_char
			JOIN sign_char_owner USING (sign_char_id)
			WHERE sign_id = ?
			AND sign_char_owner.scroll_version_id = _scrollversion_
MYSQL

			$start_sign_id
		);

		while ($sign_scalar = $sign_stream->next_sign()) # search for end of line 0
		{
			@sign = @{ $sign_scalar };

			if ($sign[3] == 9) # end of line 0
			{
				last;
			}
		}

		if ($sign_scalar = $sign_stream->next_sign()) # begin of line 1 exists
		{
			$cgi->print('{"case":"begin of line 1 exists","start_break_type":"'.$start_break_type.'"}');

			# TODO
			# copy start break type to line 1
			# probably remove all signs of 0 from stream => save them while moving towards begin of 1
			# remove line 0 from line_to_col (needs line_id, from sign_to_line?)
		}
		else # line 0 is last one remaining => remove its content, but keep begin & end
		{
			$cgi->print('{"case":"line 0 is last one remaining","start_break_type":"'.$start_break_type.'"}');

			# TODO
			# reduce line 0 to just begin & end
			# probably remove all signs of 0 from stream
			# let begin of 0 point to end of 0 => save both sign ids
		}
	}
	else # remove line n (with n > 0)
	{
		my $is_line_start = 0;
		my $line_counter = 0;

		my $sign_id_before_line;
		my $stream_id_before_line;
		my $sign_char_id_before_line;

		my $sign_id_at_line_start;
		my $sign_char_id_at_line_start;

		my $sign_char_id_at_line_end;
		my $break_type_at_line_end;

		my $sign_id_after_line;
		my $sign_char_id_after_line;

		my $line_id;

		while ($sign_scalar = $sign_stream->next_sign()) # search for begin of line n
		{
			@sign = @{ $sign_scalar };

			if ($sign[3] == 9) # some line end or line start
			{
				if ($is_line_start)
				{
					$line_counter++;

					if ($line_counter == $line_index_to_remove)
					{
						$sign_id_at_line_start = $sign[1];
						$sign_char_id_at_line_start = $sign[13];

						last;
					}
				}

				$is_line_start = !$is_line_start;
			}

			$sign_id_before_line = $sign[1];
			$sign_char_id_before_line = $sign[13];
		}

		while ($sign_scalar = $sign_stream->next_sign()) # search for end of line n
		{
			@sign = @{ $sign_scalar };

			if ($sign[3] == 9) # end of line n
			{
				$sign_char_id_at_line_end = $sign[13];

				$break_type_at_line_end = query_SQE
				(
					$cgi,
					'first_value',

					<<'MYSQL',
					SELECT break_type FROM sign_char
					JOIN sign_char_owner USING (sign_char_id)
					WHERE sign_char_id = ?
					AND sign_char_owner.scroll_version_id = _scrollversion_
MYSQL

					$sign_char_id_at_line_end
				);

				last;
			}
		}

		if ($sign_scalar = $sign_stream->next_sign()) # begin of line n+1 exists
		{
			@sign = @{ $sign_scalar };

			$sign_id_after_line = $sign[1];
			$sign_char_id_after_line = $sign[13];

			$stream_id_before_line = query_SQE
			(
				$cgi,
				'first_value',

				<<'MYSQL',
				SELECT position_in_stream_id FROM position_in_stream
				JOIN position_in_stream_owner USING (position_in_stream_id)
				WHERE sign_id = ?
				AND position_in_stream_owner.scroll_version_id = _scrollversion_
MYSQL

				$sign_id_before_line
			);

			$line_id = query_SQE
			(
				$cgi,
				'first_value',

				<<'MYSQL',
				SELECT line_id FROM line_to_sign
				JOIN line_to_sign_owner USING (line_to_sign_id)
				WHERE sign_id = ?
				AND line_to_sign_owner.scroll_version_id = _scrollversion_
MYSQL

				$sign_id_at_line_start
			);

			$cgi->print
			(
				'{'
				.'"case":"begin of line n+1 exists"'
				.',"$stream_id_before_line":'.$stream_id_before_line
				.',"$sign_id_before_line":'.$sign_id_before_line
				.',"$sign_id_at_line_start":'.$sign_id_at_line_start
				.',"$sign_id_after_line":'.$sign_id_after_line
				.',"$sign_char_id_before_line":'.$sign_char_id_before_line
				.',"$sign_char_id_at_line_start":'.$sign_char_id_at_line_start
				.',"$sign_char_id_at_line_end":'.$sign_char_id_at_line_end
				.',"$sign_char_id_after_line":'.$sign_char_id_after_line
				.',"$line_id":'.$line_id
				.'}'
			);

			return;

			# TODO probably remove all signs of line 0 from stream => save them while moving towards begin of 1
			my @result = $dbh->change_value # change sign stream entry to ignore line
			(
				'position_in_stream',
				$stream_id_before_line,
				'next_sign',
				$sign_id_after_line
			);

			if (defined $result[1])
			{
				$cgi->print('{"error":"'.${$result[1]}[1].'","case":"begin of line n+1 exists","situation":"change sign stream entry"}');
				return;
			}

			@result = $dbh->remove_entry
			(
				'col_to_line',
				$line_id
			);

			if (defined $result[1])
			{
				$cgi->print('{"error":"'.${$result[1]}[1].'","case":"begin of line n+1 exists","situation":"remove col_to_line entry"}');
				return;
			}
		}
		else # line n is last one
		{
			$cgi->print('{"case":"line n is the last one","$sign_id_before_line":'.$sign_id_before_line.'}');





			$cgi->print
			(
				'{'
				.'"case":"begin of line n+1 exists"'
				.',"$stream_id_before_line":'.$stream_id_before_line
				.',"$sign_id_before_line":'.$sign_id_before_line
				.',"$sign_id_at_line_start":'.$sign_id_at_line_start
				.',"$sign_id_after_line":'.$sign_id_after_line
				.',"$sign_char_id_before_line":'.$sign_char_id_before_line
				.',"$sign_char_id_at_line_start":'.$sign_char_id_at_line_start
				.',"$sign_char_id_at_line_end":'.$sign_char_id_at_line_end
				.',"$sign_char_id_after_line":'.$sign_char_id_after_line
				.',"$break_type_at_line_end":"'.$break_type_at_line_end.'"'
				.',"$line_id":'.$line_id
				.'}'
			);

			return;

			my @result = $dbh->change_value # copy break_type end information to previous line
			(
				'sign_char',
				$sign_char_id_before_line,
				'break_type',
				$break_type_at_line_end # either (LINE_START,COL_START) or (LINE_START,COL_START,SCROLL_START)
			);

			if (defined $result[1])
			{
				$cgi->print('{"error":"'.${$result[1]}[1].'","case":"begin of line n+1 exists","situation":"copy break type"}');
				return;
			}



			# TODO
			# reduce line 0 to just begin & end
			# probably remove all signs of 0 from stream
			# let begin of 0 point to end of 0 => save both sign ids
		}
	}

	return;














		# search for start of line

#	my $sign_id_before_line;
#	my $stream_id_before_line;
#	my $sign_char_id_before_line;
#
#	my $start_break_type;
#	if ($line_index_to_remove == 0)
#	{
		# stream has no crossfragment connections => x_id_before_line values stay undefined

#		($stream_id_before_line, $sign_id_before_line) = query_SQE # is defined exactly when not begin of scroll
#		(
#			$cgi,
#			'first_array',
#
#			<<'MYSQL',
#			SELECT position_in_stream_id, sign_id FROM position_in_stream
#			JOIN position_in_stream_owner USING (position_in_stream_id)
#			WHERE next_sign_id = ?
#			AND position_in_stream_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#			$start_sign_id
#		);
#
#		if (defined $sign_id_before_line)
#		{
#			$sign_char_id_before_line = query_SQE
#			(
#				$cgi,
#				'first_value',
#
#				<<'MYSQL',
#				SELECT sign_char_id FROM sign_char
#				JOIN sign_char_owner USING (sign_char_id)
#				WHERE sign_id = ?
#				AND sign_char_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#				$sign_id_before_line
#			);
#		}

#		$start_break_type = query_SQE
#		(
#			$cgi,
#			'first_value',
#
#			<<'MYSQL',
#			SELECT break_type FROM sign_char
#			JOIN sign_char_owner USING (sign_char_id)
#			WHERE sign_id = ?
#			AND sign_char_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#			$start_sign_id
#		);
#	}
#	else # search through stream for begin of nth line (n > 0)
#	{
#		my $sign_scalar; # as scalar first for simple check whether existent
#		my @sign;
#
#		my $is_line_start = 0;
#		my $line_counter = 0;
#		my $line_start_sign_char_id;
#
#		while ($sign_scalar = $sign_stream->next_sign())
#		{
#			@sign = @{ $sign_scalar };
#			if ($sign[3] == 9) # line end or line start
#			{
#				if ($is_line_start)
#				{
#					$line_counter++;
#
#					if ($line_counter == $line_index_to_remove)
#					{
#						$line_start_sign_char_id = $sign[13];
#
#						last;
#					}
#				}
#
#				$is_line_start = !$is_line_start;
#			}
#
#			$sign_id_before_line = $sign[1];
#			$sign_char_id_before_line = $sign[13];
#		}
#
#		if (!defined $line_start_sign_char_id)
#		{
#			$cgi->print('{"error":"could not find line start"}');
#			return;
#		}
#
#		$stream_id_before_line = query_SQE
#		(
#			$cgi,
#			'first_value',
#
#			<<'MYSQL',
#			SELECT position_in_stream_id FROM position_in_stream
#			JOIN position_in_stream_owner USING (position_in_stream_id)
#			WHERE sign_id = ?
#  			AND position_in_stream_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#			$sign_id_before_line
#		);
#
#		$start_break_type = query_SQE
#		(
#			$cgi,
#			'first_value',
#
#			<<'MYSQL',
#			SELECT break_type FROM sign_char
#			JOIN sign_char_owner USING (sign_char_id)
#			WHERE sign_char_id = ?
#	  		AND sign_char_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#			$line_start_sign_char_id
#		);
#	}

#	my $start_is_column_start = 0;
#	my $start_is_scroll_start = 0;
#
#	if (index($break_type, 'COLUMN_START') != -1) # line begin is also column begin
#	{
#		$start_is_column_start = 1;
#
#		if (index($break_type, 'SCROLL_START') != -1) # column begin is also scroll begin
#		{
#			$start_is_scroll_start = 1;
#		}
#	}

	# search for end of line

#	my $sign_scalar;
#	my @sign;
#
#	my $line_end_sign_char_id;
#
#	while ($sign_scalar = $sign_stream->next_sign())
#	{
#		@sign = @{ $sign_scalar };
#
#		if ($sign[3] == 9) # line end
#		{
#			$line_end_sign_char_id = $sign[13];
#
#			last;
#		}
#	}
#
#	if (!defined $line_end_sign_char_id)
#	{
#		$cgi->print('{"error":"could not find line end"}');
#		return;
#	}
#
#	my $end_break_type = query_SQE
#	(
#		$cgi,
#		'first_value',
#
#		<<'MYSQL',
#		SELECT break_type FROM sign_char
#		JOIN sign_char_owner USING (sign_char_id)
#		WHERE sign_char_id = ?
#	  	AND sign_char_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#		$line_end_sign_char_id
#	);

#	my $end_is_column_end = 0;
#	my $end_is_scroll_end = 0;
#
#	if (index($break_type, 'COLUMN_END') != -1)
#	{
#		$end_is_column_end = 1;
#
#		if (index($break_type, 'SCROLL_END') != -1)
#		{
#			$end_is_scroll_end = 1;
#		}
#	}

	# check sign after end of line

#	my $stream_id_after_line;
#	my $sign_char_id_after_line;
#
#	$sign_scalar = $sign_stream->next_sign();
#	if (defined $sign_scalar)
#	{
#		@sign = @{ $sign_scalar };
#
#		$stream_id_after_line = query_SQE
#		(
#			$cgi,
#			'first_value',
#
#			<<'MYSQL',
#			SELECT position_in_stream_id FROM position_in_stream
#			JOIN position_in_stream_owner USING (position_in_stream_id)
#			WHERE sign_id = ?
#	  		AND position_in_stream_owner.scroll_version_id = _scrollversion_
#MYSQL
#
#			$sign[1]
#		);
#
#		$sign_char_id_after_line = $sign[13];
#	}
#
#	$cgi->print('{"data":['
#	.$stream_id_before_line.','
#	.$stream_id_after_line.','
#	.$sign_char_id_before_line.','
#	.$sign_char_id_after_line.','
#	.$start_break_type.','
#	.$end_break_type
##	.$start_is_scroll_start.','
##	.$end_is_scroll_end
#	.']}');
#
#	return;


	# change pointer to bypass 'removed' line

	# apply change_value to let X point to Y
	#   start was COLUMN_START:
	#     end was COLUMN_END: remove line, but keep starting & ending break
	#     end was not COLUMN_END: remove complete line, change_value to add COLUMN_START to Y
	#     start was SCROLL_START:
	#       end was SCROLL_END: remove line, but keep starting & ending break (already covered by COLUMN_START & COLUMN_END)
	#       end was not SCROLL_END: remove complete line, change_value to add SCROLL_START to Y
	#   start was not COLUMN_START:






#	my @result;
#	if (defined $stream_id_before_line
#	&&  defined $sign_char_id_before_line) # both ids should be defined at the same time (or both undefined)
#	{
#		@result = $dbh->change_value
#		(
#			'position_in_stream',
#			$stream_id_before_line,
#			'next_sign_id',
#			$stream_id_after_line # might be NULL if entire stream ends after removed line
#		);
#
#		if (defined $result[1])
#		{
#			$cgi->print('{"error":"'.${$result[1]}[1].'"}');
#			return;
#		}
#
#		if ( $start_is_column_start
#		&&  !$end_is_column_end)
#		{
#			my $break_type_string = '(LINE_START,COLUMN_START';
#
#			if ( $start_is_scroll_start
#			&&  !$end_is_scroll_end)
#			{
#				$break_type_string .= ',SCROLL_START';
#			}
#
#			$break_type_string .= ')';
#
#			@result = $dbh->change_value
#			(
#				'sign_char',
#				$sign_char_id_before_line,
#				'break_type',
#				$break_type_string
#			);
#
#			if (defined $result[1])
#			{
#				# TODO undo previous change_value to get back to original state
#				$cgi->print('{"error":"'.${$result[1]}[1].'"}');
#				return;
#			}
#
#		}
#		# TODO remove everything relevant in line_to_sign, (probably) col_to_line, (probably) scroll_to_col
#
#
#		my $start_is_column_start = 0;
#		my $start_is_scroll_start = 0;
#		my $end_is_column_end = 0;
#		my $end_is_scroll_end = 0;
#
#
#
#
#
#	}
#	else
#	{
#
#
#	}
#
#
#	$json_string .= '}';
#	$cgi->print($json_string);


	# TODO
	# for testing: only search IDs of LINE_START and LINE_END, determine case
	# parameters: scrollversion, fragmentId (must be added at load_fragment_text), lineIndex
	# get sign stream for fragment (and implicitely for given scroll_version)
	#
	# move to lineIndexTh LINE_START (sign_char.break_type)
	#   check if also COLUMN_START (should be redundant with lineIndex == 0, but that's not guaranteed)
	#   if yes: check also if SCROLL_START
	#   save sign_id of sign X before this LINE_START (might be null / nonexistent for 1QS 1, 1)
	# move to next LINE_END
	#   check if also COLUMN_END
	#   if yes: check also if SCROLL_END
	#   save sign_id of sign Y after this LINE_END (might be null)
	# apply change_value to let X point to Y
	#   start was COLUMN_START:
	#     end was COLUMN_END: remove line, but keep starting & ending break
	#     end was not COLUMN_END: remove complete line, change_value to add COLUMN_START to Y
	#     start was SCROLL_START:
	#       end was SCROLL_END: remove line, but keep starting & ending break (already covered by COLUMN_START & COLUMN_END)
	#       end was not SCROLL_END: remove complete line, change_value to add SCROLL_START to Y
	#   start was not COLUMN_START:
}

sub locate_sign
{
	my $cgi = shift;
	my $sign_id = $cgi->param('signId');

	my $sign_char = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT sign FROM sign_char
		WHERE sign_id = ?
MYSQL

		$sign_id
	);
	my $line_id = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT line_id FROM line_to_sign
		WHERE sign_id = ?
MYSQL

		$sign_id
	);
	my $line_name = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT name FROM line_data
		WHERE line_id = ?
MYSQL

		$line_id
	);
	my $col_id = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT col_id FROM col_to_line
		WHERE line_id = ?
MYSQL

		$line_id
	);
	my $col_name = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT name FROM col_data
		WHERE col_id = ?
MYSQL

		$col_id
	);
	my $scroll_id = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT scroll_id FROM scroll_to_col
		WHERE col_id = ?
MYSQL

		$col_id
	);
	my $scroll_name = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT name FROM scroll_data
		WHERE scroll_id = ?
MYSQL

		$scroll_id
	);

	my $json =
	'{'
	.'"scrollName":"'.$scroll_name.'"'
	.',"scrollId":'.$scroll_id
	.',"columnName":"'.$col_name.'"'
	.',"columnId":'.$col_id
	.',"lineName":"'.$line_name.'"'
	.',"lineId":'.$line_id
	.',"qwbMainChar":"'.$sign_char.'"'
	.',"signId":'.$sign_id
	.'}';

	$cgi->print($json);
}

sub potentially_save_new_variant
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my %new_variant = %{ decode_json($cgi->param('variant')) };
	
	# set dummy values for stringification
	if (! defined $new_variant{'mightBeWider'})
	{
		$new_variant{'mightBeWider'} = 0;
	}
	if (! defined $new_variant{'reconstructed'})
	{
		$new_variant{'reconstructed'} = 0;
	}
	if (! defined $new_variant{'retraced'})
	{
		$new_variant{'retraced'} = 0;
	}
	if (! defined $new_variant{'commentary'})
	{
		$new_variant{'commentary'} = '';
	}
	
	# stringify for comparison
	
	my $new_variant_stringified
	=  $new_variant{'sign'         }.'§'
	. ($new_variant{'width'} * 1000).'§' # neutralizes decimal formatting issues
	.  $new_variant{'mightBeWider' }.'§'
	.  $new_variant{'reconstructed'}.'§'
	.  $new_variant{'retraced'     }.'§'
	.  $new_variant{'commentary'   }.'§'
	.  $new_variant{'corrected'    }.'§'
	.  $new_variant{'position'     }.'§';
	
	say '$new_variant_stringified '.$new_variant_stringified;
	  
	my @existingSigns = queryAll
	(
		'SELECT *'
		.' FROM sign'
		.' WHERE sign_id = '.$new_variant{'mainSignId'}
		.' OR sign_id IN'
		
		.' ('
		.'    SELECT sign_id'
		.'    FROM is_variant_sign_of' 
		.'    WHERE main_sign_id = '.$new_variant{'mainSignId'}
		.' )'
	);
	
	my @sign_strings;
	my $sign_amount = (scalar @existingSigns) / 17;
	
	my $is_new_variant = 1;
	
	for (my $i_sign = 0; $i_sign < $sign_amount; $i_sign++)
	{
		my $position = queryResult
		(
			'SELECT type'
			.' FROM sign_relative_position'
			.' WHERE sign_relative_position_id = '.$existingSigns[$i_sign * 17],
			$dbh
		);
		
		my $sign_string = ''
		. $existingSigns[$i_sign * 17 +  2].'§' # actual sign
		.($existingSigns[$i_sign * 17 +  4] * 1000).'§' # width, multiplied with 1000 to standardize formatting
		. $existingSigns[$i_sign * 17 +  5].'§' # might be wider
		. $existingSigns[$i_sign * 17 +  9].'§' # reconstructed
		. $existingSigns[$i_sign * 17 + 10].'§' # retraced
		. $existingSigns[$i_sign * 17 + 13].'§' # commentary
		. $existingSigns[$i_sign * 17 + 16].'§' # correction
		. $position                        .'§';
		
		say '$sign_string '.$sign_string;
		
		if ($sign_string eq $new_variant_stringified)
		{
			$is_new_variant = 0;
			last;
		}
	}
	
	if (!$is_new_variant)
	{
		print 0;
		return;
	}
	
	# save to table sign # TODO
	
	my $sql_query = 'INSERT INTO sign SET ';
	if (defined $new_variant{'sign'})
	{
		$sql_query .= 'sign = "'.$new_variant{'sign'}.'",';
	}
	if ($new_variant{'width' != 1})
	{
		$sql_query .= 'width = '.$new_variant{'width'}.',';
	}
	if (defined $new_variant{'corrected'})
	{
		$sql_query .= 'correction = "'.$new_variant{'corrected'}.'",';
	}
	$sql_query .= 'might_be_wider = '.$new_variant{'mightBeWider'}.',';
	$sql_query .= 'readability = "COMPLETE",';
	$sql_query .= 'is_reconstructed = '.$new_variant{'reconstructed'}.',';
	$sql_query .= 'is_retraced = '.$new_variant{'retraced'}.',';
	$sql_query .= 'commentary = "'.$new_variant{'commentary'}.'",';
	$sql_query .= 'real_areas_id = '.$existingSigns[14].',';
	
	$sql_query = substr($sql_query, 0, (length $sql_query) - 1); # remove final ,
	query
	(
		$sql_query, 
		$dbh
	);
	
	my $sign_id = lastInsertedId();
	my $user_id = userId $cgi->param('user');
	if (undef $user_id || $user_id == '')
	{
		$user_id = 5; # TODO
	}
	
	# table sign_owner
	query # TODO set proper version
	(
		'INSERT INTO sign_owner'
		.' SET sign_id = '.$sign_id
		.' , user_id = '.$user_id,
		$dbh
	);
	
	# table sign_relative_position
	if (defined $new_variant{'position'})
	{
		query
		(
			'INSERT INTO sign_relative_position'
			.' SET sign_relative_position_id = '.$sign_id
			.' , type = '.$new_variant{'position'},
			$dbh
		);
	}
	
	# table is_variant_sign_of
	query # TODO proper rank
	(
		'INSERT INTO is_variant_sign_of'
		.' SET main_sign_id = '.$new_variant{'mainSignId'}
		.' , sign_id = '.$sign_id,
		$dbh
	);
}

sub saveBreak
{
	my ($break_type, $user_id, $previous_position_id) = (shift, shift, shift);
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	
	query
	(
		'INSERT INTO sign '
		.'SET sign = "|"'
		.', sign_type_id = 9'
		.', break_type = "'.$break_type.'"',
		$dbh
	);
	my $sign_id = lastInsertedId();
		
	query
	(
		'INSERT INTO sign_owner '
		.'VALUES ('.$sign_id.', '.$user_id.', now())',
		$dbh
	);
	
	my $current_pos_in_stream_id = saveToStream
	(
		$sign_id,
		$previous_position_id
	);
	
	return ($sign_id, $current_pos_in_stream_id);
}

sub saveSigns
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my $user_name = $cgi->param('user');
	my $user_id = userId($user_name);
	if (!defined $user_id)
	{
		say 'error: not logged in when saving signs';
		return;
	}
	
	my $input = $cgi->param('signs');
	say 'JSON: '.$input."\n";
	
	my $decoded = decode_json $input;
	
	my %signType2Id =
	(
		'space'				=> 2,
		'possibleVacat'		=> 3,
		'vacat'				=> 4,
		'damage'			=> 5,
		'blankLine'			=> 6,
		'paragraphMarker'	=> 7,
		'lacuna'			=> 8
	);
	my %signType2Char =
	(
		'space'			=> '" "',
		'possibleVacat'	=> '" "',
		'vacat'			=> '" "'
	);
	my %vocalization2Id =
	(
		'Tiberian'		=> 1,
		'Babylonian'	=> 2,
		'Palestinian'	=> 3
	);
	my %position2Enum =
	(
		'aboveLine'		=> 'ABOVE_LINE',
		'belowLine'		=> 'BELOW_LINE',
		'leftMargin'	=> 'LEFT_MARGIN',
		'rightMargin'	=> 'RIGHT_MARGIN'
	);
	my %correction2Enum =
	(
		'overwritten'		=> 'OVERWRITTEN',
		'horizontalLine'	=> 'HORIZONTAL_LINE',
		'diagonalLeftLine'	=> 'DIAGONAL_LEFT_LINE',
		'diagonalRightLine'	=> 'DIAGONAL_RIGHT_LINE',
		'dotBelow'			=> 'DOT_BELOW',
		'dotAbove'			=> 'DOT_ABOVE',
		'lineBelow'			=> 'LINE_BELOW',
		'lineAbove'			=> 'LINE_ABOVE',
		'boxed'				=> 'BOXED',
		'erased'			=> 'ERASED'
	);
	
	my @lines = @{$decoded};
	my $a;
	my $main_sign_id;
	my $position_level;
	my $scroll_id;
	
	# TODO break for scroll start, if fitting
	
	# TODO begin of input is probably not begin of column => check line tag first
	my ($previous_sign_id, $previous_stream_position_id)
	= saveBreak('COLUMN_START', $user_id, undef);
	
	foreach my $line (@lines) # TODO combine queries for all signs
	{
		# assume that line always starts with first sign
		($previous_sign_id, $previous_stream_position_id)
		= saveBreak('LINE_START', $user_id, $previous_stream_position_id);
		
		my @alternatives = @{$line};
		
		# no signs in this line => insert 'blank line' sign
		if (scalar @alternatives == 0)
		{
			@alternatives = ([{'sign' => 'blankLine'}]);
		}
		
		foreach my $alternative (@alternatives)
		{
			my $is_variant_sign = 0; # set to main sign
			
			my @signs = @{$alternative};
			foreach my $sign (@signs)
			{
				my %sign_entries = ();
				# assumed default values set by DB:
				# sign_type_id = 1, width = 1, might_be_wider = 0, vocalization_id = null
				# readability = null, readable_areas = (NW,NE,MW,ME,SW,SE)
				# is_reconstructed = 0, is_retraced = 0, deletion = null (not deleted)
				# form_of_writing_id = 0
				# editorial_flag = null
				# no commentary at sign_comment
				
				# transform from JSON to DB
				# TODO prohibit code injection
				
				my %attributes = %{$sign};
				
				if ($a = $attributes{'sign'})
				{
					if ($signType2Id{$a})
					{
						$sign_entries{'sign_type_id'} = $signType2Id{$a};
						
						if (my $char = $signType2Char{$a}) # space, vacat, possibleVacat -> single whitespace sign
						{
							$sign_entries{'sign'} = $char;
						}
					}
					elsif ($a =~ /[\x{05d0}-\x{05ea}]/) # Hebrew letter (context or final, but nothing special else)
					{
						# sign_type_id is already 1 (letter) by default
						$sign_entries{'sign'} = '\''.$a.'\''; # will remain empty string otherwise
					}
				}
				if ($a = $attributes{'width'})
				{
					if ($a =~ /[0-9]*(.[0-9]*)?/
					and $a > 0) # positive float
					{
						$sign_entries{'width'} = $a;
					}
				}
				if ($a = $attributes{'atLeast'})
				{
					if ($a eq 'true')
					{
						$sign_entries{'might_be_wider'} = 1;
					}
				}
				if ($a = $attributes{'vocalization'})
				{
					# TODO needs separate table, then usage of vocalization_id
					
					if ($vocalization2Id{$a})
					{
						# $sign_entries{'vocalization'} = $vocalization2Id{$a};
					}
				}
				
				if ($a = $attributes{'manuscript'})
				{
					$scroll_id = queryResult
					(
						'SELECT scroll_id FROM scroll WHERE name = "'
						.$a
						.'"',
						$dbh
					);
					# if null, connection to scroll will be ignored
					 
					# TODO restrict to scrolls the user has access to
					# TODO there might be multiple scrolls with the same name the user has access to
				}
				if ($a = $attributes{'fragment'}) # TODO evaluate, assume 1 otherwise?
				{
					$sign_entries{'fragment'} = $a;
				}
				if ($a = $attributes{'line'}) # TODO evaluate, assume 1 (and increasing) otherwise?
				{
					$sign_entries{'line'} = $a;
				}
				if ($a = $attributes{'scribe_id'})
				{
					if ($a =~ /[0-9]+/
					and $a > 0) # positive integer
					{
						# TODO add later
						# $sign_entries{'scribe_id'} = $a;
					}
				}
				
				if ($a = $attributes{'readability'}) # COMPLETE / INCOMPLETE_BUT_CLEAR / INCOMPLETE_AND_NOT_CLEAR
				{
					# TODO damaged: clear / unclear
				}
				if ($a = $attributes{'readable_areas'}) # set 'NW,NE,MW,ME,SW,SE'
				{
					# TODO
				}
				if ($a = $attributes{'reconstructed'})
				{
					if ($a eq 'true')
					{
						$sign_entries{'is_reconstructed'} = 1;	
					}
				}
				if ($a = $attributes{'retraced'})
				{
					if ($a eq 'true')
					{
						$sign_entries{'is_retraced'} = 1;	
					}
				}
				
				if ($a = $attributes{'suggested'})
				{
					if ($a eq '')
					{
						$sign_entries{'editorial_flag'} = '"SHOULD_BE_DELETED"';
					}
					elsif ($attributes{'sign'} eq '') # no sign to be read, but one suggested
					{
						$sign_entries{'sign'} = $a;
						$sign_entries{'editorial_flag'} = '"SHOULD_BE_ADDED"';
					}
					else
					{
						# TODO to alternative sign, link main sign and it
						$sign_entries{'editorial_flag'} = '"CONJECTURE"';
					}
				}
				
				say Dumper(%sign_entries);
				
				# TODO check whether sign already exists (then only add it to the new user)
				
				# save sign itself
				my $sql_query = 'INSERT INTO sign SET ';
				while (my ($key, $value) = each %sign_entries)
				{
					$sql_query .= $key.'='.$value.','
				}
				$sql_query = substr($sql_query, 0, (length $sql_query) - 1); # remove final ,
				query
				(
					$sql_query
				);
				
				# get id for current sign, relevant for follow-up queries
				my $sign_id = lastInsertedId();
				
				# save sign owner
				query
				(
					'INSERT INTO sign_owner VALUES ('
					.$sign_id
					.','
					.$user_id
					.',now())',
					$dbh
				);
				
				# save position
				if ($a = $attributes{'position'})
				{
					$position_level = 1;
					
					while (my ($key, $value) = each %position2Enum)
					{
						if (index($a, $key) != -1)
						{
							query
							(
								'INSERT sign_relative_position SET sign_relative_position_id = '
								.$sign_id
								.', type = \''
								.$value
								.'\', level = '
								.$position_level,
								$dbh
							);
							
							$position_level++;
						}
					}
				}
				
				# save correction
				if ($a = $attributes{'corrected'})
				{
					while (my ($key, $value) = each %correction2Enum)
					{
						if (index($a, $key) != -1)
						{
							query
							(
								'INSERT INTO sign_correction (sign_id, correction) VALUES ('
								.$sign_id
								.', \''
								.$value.'\')',
								$dbh
							); 
						}
					}
				}
				
				# save alternatives and stream position
				if ($is_variant_sign)
				{
					query
					(
						'INSERT INTO is_variant_sign_of VALUES ('
						.$main_sign_id
						.','
						.$sign_id
						.',1)',
						$dbh
					);
					
					# no direct link to sign stream, but indirectly via is_variant_sign_of
				}
				else # first sign of alternative (maybe the only one)
				{
					$previous_stream_position_id = saveToStream
					(
						$sign_id,
						$previous_stream_position_id
					);
					
					$main_sign_id = $sign_id;
					$is_variant_sign = 1; # for next signs of alternative (if existing)	
				}
				
				# save user's comment
				if ($a = $attributes{'comment'})
				{
					query # TODO later save in 1..n sign_comment table
					(
						'UPDATE sign'
						.' SET commentary = "'.$a.'"'
						.' WHERE sign_id = '.$sign_id,
						$dbh
					);
				}
				
				# save connection to scroll
				if ($scroll_id != undef)
				{
					query
					(
						'INSERT real_area'
						.' SET scroll_id = '.$scroll_id,
						$dbh
					);
					
					query
					(
						'UPDATE sign'
						.' SET real_areas_id = '.lastInsertedId()
						.' WHERE sign_id = '.$sign_id,
						$dbh
					);
				}
				
				say 'saved to DB';
			}
		}
		
		($previous_sign_id, $previous_stream_position_id)
		= saveBreak('LINE_END', $user_id, $previous_stream_position_id);
	}
	
	saveBreak('COLUMN_END', $user_id, $previous_stream_position_id);
	
	# TODO break for scroll end, if fitting
}


# MAIN

sub main
{
	my ($cgi, $error) = SQE_CGI->new; # includes processing of session id / (user name + pw)
	if (defined $error)
	{
		$cgi = CGI->new; # fall back to normal CGI
		print $cgi->header('application/json; charset=utf-8');
		print '{"errorCode":'.@{$error}[0].',"error":"'.@{$error}[1].'"}';
		exit;
	}
	
	print $cgi->header('application/json; charset=utf-8');
	
	
	# handle requests
	
	my %request2Sub =
	(
		'login'            => \&login,
		'loadFragmentText' => \&load_fragment_text,

		'addChar'          => \&add_char,
		'changeWidth'      => \&change_width,
		'addAttribute'     => \&add_attribute,
		'removeAttribute'  => \&remove_attribute,

		'addLine'          => \&add_line,
		'removeLine'       => \&remove_line,

		'locateSign'       => \&locate_sign
	);
	
	my $request = $cgi->param('request');
	if (defined $request2Sub{$request})
	{
		$request2Sub{$request}->($cgi, $error);
	}
	else
	{
		print encode_json(
		{
			'error',
			"Request '".$request."' not understood."
		});
	}
}

main();