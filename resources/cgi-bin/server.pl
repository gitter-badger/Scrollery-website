#! /usr/bin/perl
# C:\Strawberry\perl\bin\perl.exe

use strict;
use warnings;

use feature qw(say);
use Data::Dumper;

use lib qw(/home/perl_libs);
#use lib qw(C:/Users/Martin/Desktop/martin/qumran/Entwicklung/Workspace/Scrollery/cgi-bin-ingo/);
use SQE_CGI;
use SQE_DBI;
use SQE_API::Queries;

use CGI;
use JSON;

# helper functions

sub query_SQE
{
	my ($cgi, $result_type, $query_text, @query_parameters) = (@_);
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

		<<'MYSQL'
		SELECT LAST_INSERT_ID()
MYSQL
);
}

sub query
{
	my $sql_command = shift;
	my $dbh = shift;
	# if (index($sql_command, 'user_sessions') == -1)
	# {
	# 	say '$sql_command '.$sql_command;
	# }

	my $query = $dbh->prepare($sql_command) or die DBI->errstr;
	$query->execute(@_) or die DBI->errstr;
	$query->finish();
}

sub queryResult
{
	my $sql_command = shift;
	my $dbh = shift;

	# say '$sql_command '.$sql_command;

	my $query = $dbh->prepare($sql_command) or die DBI->errstr;
	$query->execute(@_) or die DBI->errstr;

	my @row = $query->fetchrow_array();
	my $returnValue = $row[0];

	$query->finish();

	return $returnValue;
}

sub queryResultPrepared
{
	my $prepared_query = shift;

	my $i_param = 1;
	foreach my $param (@_)
	{
	    $prepared_query->bind_param($i_param, $param);
	    $i_param++;
    }

	$prepared_query->execute() or die DBI->errstr;
	my $returnValue = ($prepared_query->fetchrow_array())[0];
	$prepared_query->finish();

	return $returnValue;
}

sub queryAllPrepared
{
	my $prepared_query = shift;

	my $i_param = 1;
	foreach my $param (@_)
	{
	    $prepared_query->bind_param($i_param, $param);
	    $i_param++;
    }

	$prepared_query->execute() or die DBI->errstr;
	my @returnValue = $prepared_query->fetchrow_array();
	$prepared_query->finish();

	return @returnValue;
}

sub queryAll
{
	my $sql_command = shift;
	my $dbh = shift;

	my $query = $dbh->prepare($sql_command);
	$query->execute(@_);

	my @row;
	my @allResults;
	while (@row = $query->fetchrow_array())
	{
		push @allResults, @row;
	}

	$query->finish();
	return @allResults;
}

sub queryAllRows
{
	my $sql_command = shift;
	my $dbh = shift;

	my $query = $dbh->prepare($sql_command);
	$query->execute();

	my @row;
	my %allRows = {};
	my $allRowsIndex = 0;

	while (@row = $query->fetchrow_array())
	{
		$allRows{$allRowsIndex} = @row;
		$allRowsIndex++;
	}

	$query->finish();
	return %allRows;
}

sub lastInsertedId()
{
	return queryResult
	(
		<<'MYSQL'
		SELECT LAST_INSERT_ID()
MYSQL
	);
}


# functions related to client requests

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
		<<'MYSQL',
		UPDATE user_sessions
		SET session_end = NOW(),
			current = false
		WHERE user_id=?
		      AND current = true
MYSQL
		$dbh,
		$user_id
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

sub load # TODO combine queries where possible, for better performance
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my $disc_can_ref_id = $cgi->param('disc_can_ref_id'); # could be a fragment also

	my %id2SignType;
	my @sign_types = queryAll
	(
		<<'MYSQL',
		SELECT sign_type_id,
			type
		FROM sign_type
MYSQL
		$dbh
	);
	for (my $i = 0; $i < scalar @sign_types; $i += 2)
	{
		$id2SignType{$sign_types[$i]} = $sign_types[$i + 1];
	}

	my $column_start_sign_id = queryResult # TODO scroll owner relevant?
	(
		<<'MYSQL',
		SELECT sign.sign_id
		FROM sign
			JOIN real_area
				ON real_area.real_area_id = sign.real_areas_id
			JOIN line
				ON line.line_id = real_area.line_id
			JOIN column_of_scroll
				ON column_of_scroll.column_of_scroll_id = line.column_id
			JOIN discrete_canonical_references
				ON discrete_canonical_references.column_of_scroll_id = column_of_scroll.column_of_scroll_id
			JOIN scroll
				ON scroll.scroll_id = discrete_canonical_references.discrete_canonical_name_id
		WHERE FIND_IN_SET("COLUMN_START", sign.break_type) > 0
		      AND discrete_canonical_references.discrete_canonical_reference_id = ?
MYSQL
		$dbh,
		$disc_can_ref_id
	);
	if (!defined $column_start_sign_id)
	{
		print 0;
		return;
	}
	my $next_sign_id = $column_start_sign_id;

	# prepare queries
	my $get_next_sign_id_query = $dbh->prepare
	(
		<<'MYSQL'
		SELECT next_sign_id
		FROM position_in_stream
		WHERE position_in_stream.sign_id = ?
MYSQL
	);
	my $get_main_sign_query = $dbh->prepare
	(
		<<'MYSQL'
		SELECT *,
			FIND_IN_SET("COLUMN_END", sign.break_type)
		FROM sign
		WHERE sign.sign_id = ?
MYSQL
	);
#	my $get_line_id_and_name_query = $dbh->prepare
#	(
#		'SELECT line.line_id, name'
#		.' FROM line'
#
#		.' JOIN real_area'
#		.' ON real_area.line_id = line.line_id'
#
#		.' JOIN sign'
#		.' ON sign.real_areas_id = real_area.real_area_id'
#
#		.' WHERE sign.sign_id = ?'
#	);

	my $get_line_id_and_name_query = $dbh->prepare
	(
		<<'MYSQL'
		SELECT line.line_id,
			name
		FROM line
		WHERE line.line_id = (
			SELECT real_area.line_id
			FROM real_area
			WHERE real_area.real_area_id =   (
				SELECT real_areas_id
				FROM sign
				WHERE sign.sign_id = ?
			)
		)
MYSQL
	);
	my $get_variant_signs_query = $dbh->prepare
	(
		<<'MYSQL'
		SELECT *
		FROM sign
		WHERE sign_id
		      IN (
			      SELECT sign_id
			      FROM is_variant_sign_of
			      WHERE main_sign_id = ?
		      )
MYSQL
	);
	my $get_sign_position_query = $dbh->prepare
	(
		<<'MYSQL'
		SELECT type
		FROM sign_relative_position
		WHERE sign_relative_position_id = ?
		ORDER by level
MYSQL
	);

	my $json_string = '[';

	my $previous_line_id = -1;
	# TODO This variable is apparently never used.
	my $i_area_in_line;

	# build json till first column end is encountered (capped to the signs of 100,000 real areas)
	for (my $i_area = 0; $i_area < 100000; $i_area++)
	{
		# move along the position stream
		$next_sign_id = queryResultPrepared
		(
			$get_next_sign_id_query,
			$next_sign_id,
			$dbh
		);

		# get main sign from position stream
		my @main_sign = queryAllPrepared
		(
			$get_main_sign_query,
			$next_sign_id,
			$dbh
		);
		if (defined $main_sign[17]
		&&  $main_sign[17] > 0) # column end # TODO expects column end as main sign
		{
			last;
		}
		pop @main_sign; # remove column end detection to get same array length as for alternative signs

		# add new line, if needed
		my @current_line = queryAllPrepared
		(
			$get_line_id_and_name_query,
			$main_sign[0]
		);
		if ($current_line[0] != $previous_line_id) # new line started
		{
			if (length $json_string > 1) # 1+ line was already added
			{
				$json_string .= ']},'; # end previous line
			}
			$json_string .= '{"lineName":"'.$current_line[1].'","signs":[';

			$previous_line_id = $current_line[0];
		}

		# save main sign & its alternatives
		if (substr($json_string, -1) eq ']') # second or later area within line
		{
			$json_string .= ',['; # start area
		}
		else # first area
		{
			$json_string .= '[';
		}
		my @sign_data = (@main_sign, queryAllPrepared # TODO ignores 3rd alternative
		(
			$get_variant_signs_query,
			$next_sign_id
		));
		for (my $i_sign_data = 0; $i_sign_data < scalar @sign_data; $i_sign_data += 17)
		{
			if ($i_sign_data == 0) # first possible sign (and main sign) of area
			{
				$json_string .= '{';
			}
			else # later sign
			{
				$json_string .= ',{';
			}

			$json_string .= '"id":'.$sign_data[$i_sign_data];

			# skip date_of_adding

			my $a = $sign_data[$i_sign_data + 2];
			if (!($a eq '?'))
			{
				$json_string .= ',"sign":"'.$a.'"';
			}

			$a = $sign_data[$i_sign_data + 3];
			if ($a != 1) # not a letter
			{
				$json_string .= ',"signType":"'.$id2SignType{$a}.'"';
			}

			$a = $sign_data[$i_sign_data + 4];
			if ($a != 0
			&&  $a != 1) # width other than 0.0 (not a letter) and 1.0 (standard letter)
			{
				$json_string .= ',"width":'.$a;
			}

			if ($sign_data[$i_sign_data + 5] != 0) # might be wider
			{
				$json_string .= ',"mightBeWider":1';
			}

			# skip vocalization_id

			$a = $sign_data[$i_sign_data + 7];
			if (defined $a
			&&  !($a eq 'COMPLETE')) # readability impaired
			{
				$json_string .= ',"damaged":"'.$a.'"';
			}

			$a = $sign_data[$i_sign_data + 8];
			if (defined $a) # readable areas are declared
			{
				$json_string .= ',"readableAreas":"'.$a.'"';
			}

			if ($sign_data[$i_sign_data + 9] == 1) # is reconstructed
			{
				$json_string .= ',"reconstructed":1';
			}

			if ($sign_data[$i_sign_data + 10] == 1) # is retraced
			{
				$json_string .= ',"retraced":1';
			}

			# skip form_of_writing_id

			$a = $sign_data[$i_sign_data + 12];
			if (defined $a
			&&  !($a eq 'NO')) # editorial flag is set
			{
				$json_string .= ',"suggested":"'.$a.'"';
			}

			$a = $sign_data[$i_sign_data + 13];
			if (defined $a) # commentary exists
			{
				$json_string .= ',"comment":"'.$a.'"';
			}

			# skip real_areas_id

			$a = $sign_data[$i_sign_data + 15];
			if (defined $a) # break type(s)
			{
				$json_string .= ',"break":"'.$a.'"';
			}

			$a = $sign_data[$i_sign_data + 16];
			if (defined $a
			&&  !($a eq '')) # there is 1+ correction
			{
				$json_string .= ',"corrected":"'.$a.'"';
			}

			my @sign_position = queryAllPrepared
			(
				$get_sign_position_query,
				$sign_data[$i_sign_data]
			);
			if (@sign_position) # TODO level 2 positions etc.
			{
				$json_string .= ',"position":"'.$sign_position[0].'"';
			}

			$json_string .= '}';
		}
		$json_string .= ']'; # end area
	}

	if (length $json_string > 1) # 1+ line was added
	{
		$json_string .= ']}'; # close signs array and line
	}
	$json_string .= ']'; # end json

	print $json_string;
}

sub load_fragment_text
{
	my $cgi = shift;
	my $error = shift;

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
		SELECT discrete_canonical_name_id,
			column_of_scroll_id
		FROM discrete_canonical_references
		WHERE discrete_canonical_reference_id = ?
MYSQL

		$cgi->param('discreteCanonicalReferenceId')
	);
	my $fragment_id = query_SQE
	(
		$cgi,
		'first_value',

		<<'MYSQL',
		SELECT col_id
		FROM scroll_to_col
		WHERE scroll_to_col_id = ?
MYSQL

		$col_of_scroll_id
	);

	my @scroll_and_fragment_names = query_SQE
	(
		$cgi,
		'first_array',

		<<'MYSQL',
		SELECT scroll_data.name,
			col_data.name
		FROM scroll_data,
			col_data
		WHERE col_data.col_id = ?
		      AND scroll_data.scroll_id = (
				SELECT scroll_id
				FROM scroll_to_col
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
		<<'MYSQL'
		SELECT line_id
		FROM col_to_line
		WHERE col_id = ?
MYSQL
	);
	$line_ids_query->execute($fragment_id);

	my $line_name_query = $dbh->prepare_sqe
	(
		<<'MYSQL'
		SELECT name
		FROM line_data
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
	my $json_string = '{"param SCROLLVERSION":'.$scroll_version.',"actual SCROLLVERSION":'.$dbh->scrollversion().',"$col_of_scroll_id":'.$col_of_scroll_id.',"fragmentName":"'.$fragment_name.'","lines":[{"lineName":"'.$line_name.'","signs":[';

	my $first_sign_of_line = 1;

	my $current_sign_scalar; # as scalar first for simple check whether existant
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

		if ($sign[3] == 1) { $json_string .= ',"sign":"'.$sign[2].'"'; } # letter
		else               { $json_string .= ',"type":"'.$sign[3].'"'; }

		if ($sign[13] != 0) { $json_string .= ',"signCharId":'.$sign[13]; }
		if ($sign[11] != 0) { $json_string .= ',"isVariant":1'; }
		if ($sign[5]  != 1) { $json_string .= ',"width":"'.$sign[5].'"'; }
		if ($sign[6]  == 1) { $json_string .= ',"mightBeWider":1'; }

		if ($sign[12]) # sign_char_reading_data entry exists
		{
			$json_string .= ',"signCharReadingDataId":'.$sign[12];

			if (!($sign[7]  eq 'COMPLETE')) { $json_string .= ',"readability":"'.$sign[7].'"'; }
			if (  $sign[8]  == 1)           { $json_string .= ',"retraced":1'; }
			if (  $sign[9]  == 1)           { $json_string .= ',"reconstructed":1'; }
			if (!($sign[10] eq ''))         { $json_string .= ',"corrected":"'.$sign[10].'"'; }
		}

		my @sign_relative_positions = query_SQE
		(
			$cgi,
			'all',

			<<'MYSQL',
			SELECT sign_relative_position_id,
				type,
				level
			FROM sign_relative_position
			WHERE sign_id = ?
			      AND sign_relative_position_id
			          IN (
				          SELECT sign_relative_position_id
				          FROM sign_relative_position_owner
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
		$cgi->param('signCharId'),
		'width',
		$cgi->param('width')
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
			$cgi->param('signCharId'),
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
		my $type;
		if    ($attribute_value eq 'leftMargin')  { $type = 'LEFT_MARGIN'; }
		elsif ($attribute_value eq 'rightMargin') { $type = 'RIGHT_MARGIN'; }
		elsif ($attribute_value eq 'aboveLine')   { $type = 'ABOVE_LINE'; }
		elsif ($attribute_value eq 'belowLine')   { $type = 'BELOW_LINE'; }
		elsif ($attribute_value eq 'margin')      { $type = 'MARGIN'; }

		my $sign_relative_position_id = $cgi->param('signPositionId');
		if (defined $sign_relative_position_id
		&&  $sign_relative_position_id != -1)
		{
			@result = $dbh->change_value
			(
				'sign_relative_position',
				$sign_relative_position_id,
				'position',
				$type
			);
		}
		else
		{
			query_SQE
			(
				$cgi,
				'none',

				<<'MYSQL',
				INSERT INTO sign_relative_position (sign_id, type)
				VALUES (?, ?)
MYSQL

				$cgi->param('signId'),
				$type
			);
			$sign_relative_position_id = lastInsertedId_SQE($cgi);

			query_SQE
			(
				$cgi,
				'none',

				<<'MYSQL',
				INSERT INTO sign_relative_position_owner
				(sign_relative_position_id, scroll_version_id)
				VALUES (?, ?)
MYSQL

				$sign_relative_position_id,
				$scroll_version_id
			);

			$result[0] = 1;
		}

		if (defined $result[0])
		{
			$cgi->print('{"signPositionId":'.$sign_relative_position_id.'}');
		}
	}
	else # corrected / reconstructed / retraced
	{
		my ($name, $value);
		if ($attribute_name eq 'corrected')
		{
			$name = 'correction';
			$value = 'OVERWRITTEN';
		}
		else # reconstructed / retraced
		{
			$name = 'is_'.$attribute_name;
			$value = 1;
		}

		my $id = $cgi->param('signCharReadingDataId');
		if (defined $id)
		{
			@result = $dbh->change_value
			(
				'sign_char_reading_data',
				$cgi->param('signCharReadingDataId'),
				'correction',
				$value
			);
		}
		else
		{
#			@result = $dbh->add_value
#			(
#				'sign_char_reading_data',
#				0,
#				'sign_char_id',
#				$cgi->param('signCharId')
#			);

			query_SQE # TODO all entries show up on load
			(
				$cgi,
				'none',
				<<'MYSQL',
				INSERT INTO sign_char_reading_data (sign_char_id, ?)
				VALUES (?, ?)
MYSQL
				$name,
				$cgi->param('signCharId'),
				$value
			);
			$id = lastInsertedId_SQE($cgi);

			query_SQE
			(
				$cgi,
				'none',

				<<'MYSQL',
				INSERT INTO sign_char_reading_data_owner
				(sign_char_reading_data_id, scroll_version_id)
				VALUES (?, ?)
MYSQL

				$id,
				$scroll_version_id
			);

			$result[0] = $id;
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

	my $sign_id = $cgi->param('signId');
	my $attribute_name = $cgi->param('attributeName');

	my @result;
	if ($attribute_name eq 'mightBeWider')
	{
		@result = $dbh->change_value
		(
			'sign_char',
			$cgi->param('signCharId'),
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
		my @result = $dbh->remove_entry
		(
			'sign_relative_position',
			$cgi->param('signPositionId')
		);

		if (defined $result[0]) # TODO doesn't fire
		{
			$cgi->print('{"signPositionId":-1}');
		}
	}
	elsif ($attribute_name eq 'corrected')
	{
		my @result = $dbh->change_value
		(
			'sign_char_reading_data',
			$cgi->param('signCharReadingDataId'),
			'correction',
			''
		);

		if (defined $result[0])
		{
			$cgi->print('{"signCharReadingDataId":'.$result[0].'}');
		}
	}
	else # reconstructed / retraced
	{
		my @result = $dbh->change_value
		(
			'sign_char_reading_data',
			$cgi->param('signCharReadingDataId'),
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
		<<'MYSQL',
		SELECT *
		FROM sign
		WHERE sign_id = ?
		      OR sign_id
		         IN (
			         SELECT sign_id
			         FROM is_variant_sign_of
			         WHERE main_sign_id = ?
		         )
MYSQL
		$new_variant{'mainSignId'},
		$new_variant{'mainSignId'}
	);

	my @sign_strings;
	my $sign_amount = (scalar @existingSigns) / 17;

	my $is_new_variant = 1;

	for (my $i_sign = 0; $i_sign < $sign_amount; $i_sign++)
	{
		my $position = queryResult
		(
			<<'MYSQL',
			SELECT type
			FROM sign_relative_position
			WHERE sign_relative_position_id = ?
MYSQL
			$dbh,
			$existingSigns[$i_sign * 17]
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
		<<'MYSQL',
		INSERT INTO sign_owner
		SET sign_id = ?,
			user_id = ?
MYSQL
		$dbh,
		$sign_id,
		$user_id
	);

	# table sign_relative_position
	if (defined $new_variant{'position'})
	{
		query
		(
			<<'MYSQL',
			INSERT INTO sign_relative_position
			SET sign_relative_position_id = ?,
				type = ?
MYSQL
			$dbh,
			$sign_id,
			$new_variant{'position'}
		);
	}

	# table is_variant_sign_of
	query # TODO proper rank
	(
		<<'MYSQL',
		INSERT INTO is_variant_sign_of
		SET main_sign_id = ?,
			sign_id = ?
MYSQL
		$dbh,
		$new_variant{'mainSignId'},
		$sign_id
	);
}

sub save_single_sign_change
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my $user_id = userId $cgi->param('user'); # TODO replace by session check
	if (!defined $user_id)
	{
		print 0;
		return;
	}

	my @signs = @{ decode_json $cgi->param('signs') }; # main sign, afterwards variant readings

	my $idsString = '';
	my @idsArray;
	for my $sign (@signs) # collect ids of main sign & its variants
	{
		my %hash =  %{ $sign };
		my $a = $hash{'sign_id'};
		if (!defined $a)
		{
			next;
		}

		if (length $idsString > 0)
		{
			$idsString .= ',';
		}
		$idsString .= $a;

		push @idsArray, $a;
	}

	my @signs_in_db = queryAll
	(
		<<'MYSQL',
		SELECT *
		FROM sign
		WHERE sign_id
		      IN (?)
MYSQL
		$dbh,
		$idsString
	);

	# say Dumper @signs_in_db;

	for (my $i_id = 0; $i_id < scalar @idsArray; $i_id++)
	{
		my %attributes = %{ $signs[$i_id] };

#		if (%attributes{''})
#
#
#
#	2 	date_of_adding 	timestamp 			Ja 	CURRENT_TIMESTAMP 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	3 	signIndex 	char(1) 	utf8_general_ci 		Nein 	? 	the sign itself\nspaces = text-space („ „) + _is_vacat=no\nvacat = text-space + is_vacat=yes\nthe logic is: we would like to distinguish between different width of spaces without to decide beforehand whether it is an intended vacat or not. 		Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	4 	sign_type_idIndex 	tinyint(3) 		UNSIGNED 	Nein 	1 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	5 	width 	decimal(6,3) 			Nein 	1.000 	width in chars\ncan also be used as a sloppy way to estimate the place used by the sign (especially when there are no font-information), which is handy if the sign is not yet related to a real area\nFinally the value 255 marks a break with unknown width 		Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	6 	might_be_wider 	tinyint(1) 			Nein 	0 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	7 	vocalization_id 	tinyint(3) 		UNSIGNED 	Ja 	NULL 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	8 	readability 	enum('COMPLETE', 'INCOMPLETE_BUT_CLEAR', 'INCOMPLE... 	utf8_general_ci 		Ja 	NULL 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	9 	readable_areas 	set('NW', 'NE', 'MW', 'ME', 'SW', 'SE') 	utf8_general_ci 		Ja 	NULL 	2x4-field set to locate readable areas can be used to set brackets in a more sophisticated way NW NE MNW MNE MSW MSE SW SE 		Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	10 	is_reconstructed 	tinyint(1) 			Nein 	0 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	11 	is_retraced 	tinyint(1) 			Nein 	0 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	12 	form_of_writing_idIndex 	int(11) 		UNSIGNED 	Nein 	1 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	13 	editorial_flag 	enum('NO', 'CONJECTURE', 'SHOULD_BE_ADDED', 'SHOUL... 	utf8_general_ci 		Ja 	NULL 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	14 	commentary 	text 	utf8_general_ci 		Ja 	NULL 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	15 	real_areas_idIndex 	int(11) 		UNSIGNED 	Ja 	NULL 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	16 	break_type 	set('LINE_START', 'LINE_END', 'COLUMN_START', 'COL... 	utf8_general_ci 		Ja 	NULL 			Bearbeiten Bearbeiten 	Löschen Löschen
#
#    Mehr
#
#	17 	correction

	}











	# TODO
	# check whether equal to existing main sign / variant
	# if yes, skip
	# if no, create new variant
	# relevant tables: sign, sign_owner?, sign_relative_pos, is_variant_of, more?

	# assumed default values set by DB:
	# sign_type_id = 1, width = 1, might_be_wider = 0, vocalization_id = null
	# readability = null, readable_areas = (NW,NE,MW,ME,SW,SE)
	# is_reconstructed = 0, is_retraced = 0, deletion = null (not deleted)
	# form_of_writing_id = 0
	# editorial_flag = null
	# commentary = null (later: no sign_comment entry)
}

sub saveToStream
{
	my ($sign_id, $previous_pos_in_stream_id) = (shift, shift);
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;

	query
	(
		<<'MYSQL',
		INSERT INTO position_in_stream
		SET sign_id = ?
MYSQL
		$dbh,
		$sign_id
	);
	my $current_pos_in_stream_id = lastInsertedId();

	if (defined $previous_pos_in_stream_id)
	{
		query
		(
			<<'MYSQL',
			INSERT INTO next_position_in_stream
			SET position_in_stream_id = ?,
				next_position_in_stream_id = ?
MYSQL
			$dbh,
			$previous_pos_in_stream_id,
			$current_pos_in_stream_id
		);
	}

	return $current_pos_in_stream_id;
}

sub saveBreak
{
	my ($break_type, $user_id, $previous_position_id) = (shift, shift, shift);
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;

	query
	(
		<<'MYSQL',
		INSERT INTO sign
		SET sign = "|",
			sign_type_id = 9,
			break_type = "?"
MYSQL
		$dbh,
		$break_type
	);
	my $sign_id = lastInsertedId();

	query
	(
		<<'MYSQL',
		INSERT INTO sign_owner
		VALUES (?, ?, now())
MYSQL
		$dbh,
		$sign_id,
		$user_id
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
						<<'MYSQL',
						SELECT scroll_id
						FROM scroll
						WHERE name = "?"
MYSQL
						$dbh,
						$a
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
					<<'MYSQL',
					INSERT INTO sign_owner
					VALUES (?,?,now())
MYSQL
					$dbh,
					$sign_id,
					$user_id
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
								<<'MYSQL',
								INSERT sign_relative_position
								SET sign_relative_position_id = ?,
									type = '?',
									level = ?
MYSQL
								$dbh,
								$sign_id,
								$value,
								$position_level
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
								<<'MYSQL',
								INSERT INTO sign_correction (sign_id, correction)
								VALUES (?, '?')
MYSQL
								$dbh,
								$sign_id,
								$value
							);
						}
					}
				}

				# save alternatives and stream position
				if ($is_variant_sign)
				{
					query
					(
						<<'MYSQL',
						INSERT INTO is_variant_sign_of
						VALUES (?,?,1)
MYSQL
						$dbh,
						$main_sign_id,
						$sign_id

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
						<<'MYSQL',
						UPDATE sign
						SET commentary = "?"
						WHERE sign_id = ?
MYSQL
						$dbh,
						$a,
						$sign_id
					);
				}

				# save connection to scroll
				if ($scroll_id != undef)
				{
					query
					(
						<<'MYSQL',
						INSERT real_area
						SET scroll_id = ?
MYSQL
						$dbh,
						$scroll_id
					);

					query
					(
						<<'MYSQL',
						UPDATE sign
						SET real_areas_id = ?
						WHERE sign_id = ?
MYSQL
						$dbh,
						lastInsertedId(),
						$sign_id
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

sub getAllComments
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my @comments = queryAll
	(
		<<'MYSQL',
		SELECT user_id, comment_text, entry_time
		FROM user_comment
MYSQL
		$dbh
	);

	my $json_string = '[';
	for (my $i = 0; $i < scalar @comments - 2; $i += 3)
	{
		if ($i > 0)
		{
			$json_string .= ', ';
		}

		$json_string .= '{"name":"';
		$json_string .= queryResult
		(
			'SELECT user_name FROM user WHERE user_id = "'.$comments[$i].'"',
			$dbh
		);
		$json_string .= '", ';

		$json_string .=
		'"comment":"'
		.$comments[$i + 1]
		.'", ';

		$json_string .=
		'"time":"'
		.$comments[$i + 2]
		.'"}';
	}
	$json_string .= ']';

	print $json_string;
}

sub saveComment
{
	my $dbh = shift;
	my $cgi = shift;
	my $error= shift;
	my $user_name = $cgi->param('user'   );
	my $comment   = $cgi->param('comment');

	# get user id
	my $user_id = queryResult
	(
		<<'MYSQL',
		SELECT user_id
		FROM user
		WHERE user_name = "?"
MYSQL
		$dbh,
		$user_name
	);
	say '$user_id '."$user_id";

	# add comment to db
	query
	(
		<<'MYSQL',
		INSERT INTO user_comment (user_id, comment_text, entry_time)
		VALUES (?, "?", NOW())
MYSQL
		$dbh,
		$user_id,
		$comment
	);
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

#	print $cgi->header('text/plain; charset=utf-8'); # support for Hebrew etc. characters
	print $cgi->header('application/json; charset=utf-8');


	# handle requests

	my %request2Sub =
	(
		'login'            => \&login,
		'loadFragmentText' => \&load_fragment_text,

		'changeWidth'      => \&change_width,
		'addAttribute'     => \&add_attribute,
		'removeAttribute'  => \&remove_attribute,
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


#	if ($request eq 'login')
#	{
#		login($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'logout')
#	{
#		logout($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'getManifest')
#	{
#		getManifest($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'load')
#	{
#		load($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'loadFragmentText')
#	{
#		load_fragment_text($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'potentiallySaveNewVariant')
#	{
#		potentially_save_new_variant($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'saveSingleSignChange')
#	{
#		save_single_sign_change($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'saveSigns')
#	{
#		saveSigns($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'getAllComments')
#	{
#		getAllComments($dbh, $cgi, $error);
#	}
#	elsif ($request eq 'saveComment')
#	{
#		saveComment($dbh, $cgi, $error);
#	}
}

main();