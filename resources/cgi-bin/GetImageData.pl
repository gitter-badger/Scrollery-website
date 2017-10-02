#! /usr/bin/perl
# C:\Strawberry\perl\bin\perl.exe

use strict;
use warnings;
use JSON::XS;
use MIME::Base64;
use lib qw(/home/perl_libs);
#use lib qw(C:/Users/Martin/Desktop/martin/qumran/Entwicklung/Workspace/Scrollery/cgi-bin-ingo/);
use SQE_CGI;

sub processCGI {
	my ($cgi, $error) = SQE_CGI->new;
	if (defined $error)
	{
		print('{"error":"'.@{$error}[1].'"}');
		exit;
	}

	my $transaction = $cgi->param('transaction') || 'unspecified';
	my %action = (
		'getCombs' => \&getCombs,
		'getColOfComb' => \&getColOfComb,
		'getFragsOfCol' => \&getFragsOfCol,
		'getColOfScrollID' => \&getColOfScrollID,
		'imagesOfFragment' => \&getImagesOfFragment,
		'getIAAEdID' => \&getIAAEdID,
		'canonicalCompositions' => \&getCanonicalCompositions,
		'canonicalID1' => \&getCanonicalID1,
		'canonicalID2' => \&getCanonicalID2,
		'getScrollColNameFromDiscCanRef' => \&getScrollColNameFromDiscCanRef,
		'institutions' => \&getInstitutions,
		'institutionPlates' => \&getInstitutionPlates,
		'institutionFragments' => \&getInstitutionFragments,
		'institutionArtefacts' => \&getInstitutionArtefacts,
		'addArtToComb' => \&addArtToComb,
		'getScrollArtefacts' => \&getScrollArtefacts,
		'getScrollWidth' => \&getScrollWidth,
		'getScrollHeight' => \&getScrollHeight,
		'newCombination' => \&newCombination,
		'copyCombination' => \&copyCombination,
		'nameCombination' => \&nameCombination,
		'setArtPosition' => \&setArtPosition,
		'setArtRotation' => \&setArtRotation,
	);

	print $cgi->header(
				-type    => 'application/json',
				-charset =>  'utf-8',
				);

	if ($transaction eq 'unspecified'){
		print encode_json({'error', "No transaction requested."});
	} else {
		if (defined $action{$transaction}) {
			$action{$transaction}->($cgi);
		} else {
			print encode_json({'error', "Transaction type '" . $transaction . "' not understood."});
		}
	}
}
 
# General purpose DB subroutines
sub readResults {
	my $sql = shift;
	my @fetchedResults = ();
	while (my $result = $sql->fetchrow_hashref){
       	push @fetchedResults, $result;
    }
    if (scalar(@fetchedResults) > 0) {
 		print encode_json({results => \@fetchedResults});
 	} else {
    	print 'No results found.';
 	}
	$sql->finish;
}

sub handleDBError {
	my ($info, $error) = @_;
	if (defined $error) {
		print '{"error": "';
		foreach (@$error){
			print $_ . ' ';
		}
		print '"}';
	} else {
		print '{"returned_info": ' . $info . '}';
	}
}

# Various data return methods, see %action for hash table.
sub getCombs {
	my $cgi = shift;
	my $userID = $cgi->param('user');
	my $sql = $cgi->dbh->prepare_cached('select scroll_data.scroll_id as scroll_id, scroll_data.name as name, scroll_version.version as version, scroll_version.scroll_version_id as version_id, scroll_data.scroll_data_id as scroll_data_id, (SELECT COUNT(*) FROM scroll_to_col_owner WHERE scroll_to_col_owner.scroll_version_id = version_id) as count from scroll_version join scroll_data_owner using(scroll_version_id) join scroll_data using(scroll_data_id) where scroll_version.user_id = ? order by LPAD(SPLIT_STRING(name, "Q", 1), 3, "0"), LPAD(SPLIT_STRING(name, "Q", 2), 3, "0"), scroll_version.version') or die
			"Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($userID);
	readResults($sql);
	return;
}

sub getColOfComb {
	my $cgi = shift;
	my $userID = $cgi->param('user');
	my $version_id = $cgi->param('version_id');
	my $combID = $cgi->param('combID');
	my $sql = $cgi->dbh->prepare_cached('select col_data.name as name, col_data.col_id as col_id, (select count(*) from discrete_canonical_references where discrete_canonical_references.column_of_scroll_id = col_id) as count from col_data join col_data_owner using(col_data_id) join scroll_to_col using(col_id) join scroll_version using(scroll_version_id) where col_data_owner.scroll_version_id = ? and scroll_to_col.scroll_id = ?') or die
			"Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($version_id, $combID);
	readResults($sql);
	return;
}

sub getFragsOfCol {
	my $cgi = shift;
	my $userID = $cgi->param('user');
	my $version = $cgi->param('version');
	my $colID = $cgi->param('colID');
	my $sql = $cgi->dbh->prepare_cached('SELECT discrete_canonical_references.discrete_canonical_reference_id, discrete_canonical_references.column_name, discrete_canonical_references.fragment_name, discrete_canonical_references.sub_fragment_name, discrete_canonical_references.fragment_column, discrete_canonical_references.side, discrete_canonical_references.column_of_scroll_id from discrete_canonical_references where discrete_canonical_references.column_of_scroll_id = ?') or die
			"Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($colID);
	readResults($sql);
	return;
}

sub getColOfScrollID {
	my $cgi = shift;
	my $discCanRef = $cgi->param('discCanRef');
	my $sql = $cgi->dbh->prepare_cached('select scroll.name as scroll_name, column_of_scroll.name as col_name from discrete_canonical_references inner join scroll on scroll.scroll_id = discrete_canonical_references.discrete_canonical_name_id inner join column_of_scroll on column_of_scroll.column_of_scroll_id = discrete_canonical_references.column_of_scroll_id where discrete_canonical_references.discrete_canonical_reference_id = ?') or die
			"Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($discCanRef);
	readResults($sql);
	return;
}

sub getImagesOfFragment {
	my $cgi = shift;
	my $sql;
	my $idType = $cgi->param('idType');
	my $id = $cgi->param('id');
	if ($idType eq 'composition') {
		$sql = $cgi->dbh->prepare_cached('SELECT SQE_image.filename as filename, SQE_image.wavelength_start as start, SQE_image.wavelength_end as end, SQE_image.is_master, image_urls.url as url FROM SQE_image INNER JOIN image_urls on image_urls.id = SQE_image.url_code INNER JOIN image_catalog ON image_catalog.image_catalog_id = SQE_image.image_catalog_id INNER JOIN image_to_edition_catalog on image_to_edition_catalog.catalog_id = image_catalog.image_catalog_id WHERE image_to_edition_catalog.edition_id = ?') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	} elsif ($idType eq 'institution') {
		$sql = $cgi->dbh->prepare_cached('SELECT * FROM SQE_image WHERE image_catalog_id = ?') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	}
	$sql->execute($id);
	readResults($sql);
	return;
}

sub getIAAEdID {
        my $cgi = shift;
        my $discCanRef = $cgi->param('discCanRef');
        my $sql = $cgi->dbh->prepare_cached('select edition_catalog_to_discrete_reference.edition_id from edition_catalog_to_discrete_reference inner join edition_catalog on edition_catalog.edition_catalog_id = edition_catalog_to_discrete_reference.edition_id where edition_catalog.edition_side=0 and edition_catalog_to_discrete_reference.disc_can_ref_id = ?') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
        $sql->execute($discCanRef);
        readResults($sql);
        return;
}

sub getCanonicalCompositions {
	my $cgi = shift;
	my $sql = $cgi->dbh->prepare_cached('SELECT DISTINCT composition FROM edition_catalog ORDER BY BIN(composition) ASC, composition ASC') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute();
	readResults($sql);
	return;
}

sub getCanonicalID1 {
	my $cgi = shift;
	my $composition = $cgi->param('composition');
	my $sql = $cgi->dbh->prepare_cached('SELECT DISTINCT composition, edition_location_1 FROM edition_catalog WHERE composition = ? ORDER BY BIN(edition_location_1) ASC, edition_location_1 ASC') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($composition);
	readResults($sql);
	return;
}

sub getCanonicalID2 {
	my $cgi = shift;
	my $composition = $cgi->param('composition');
	my $edition_location_1 = $cgi->param('edition_location_1');
	my $sql = $cgi->dbh->prepare_cached('SELECT edition_location_2, edition_catalog_id FROM edition_catalog WHERE composition = ? AND edition_location_1 = ? AND edition_side = 0 ORDER BY CAST(edition_location_2 as unsigned)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($composition, $edition_location_1);
	readResults($sql);
	return;
}

sub getScrollColNameFromDiscCanRef {
	my $cgi = shift;
	my $frag_id = $cgi->param('frag_id');
	my $sql = $cgi->dbh->prepare_cached('SELECT scroll_data.name as scroll, col_data.name as col from scroll_to_col inner join scroll_data on scroll_data.scroll_id = scroll_to_col.scroll_id inner join col_data on col_data.col_id = scroll_to_col.col_id inner join discrete_canonical_references on discrete_canonical_references.column_of_scroll_id = scroll_to_col.col_id where discrete_canonical_references.discrete_canonical_reference_id = ?') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($frag_id);
	readResults($sql);
	return;
}

sub getInstitutions {
	my $cgi = shift;
	my $sql = $cgi->dbh->prepare_cached('SELECT DISTINCT institution FROM image_catalog') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute();
	readResults($sql);
	return;
}

sub getInstitutionPlates {
	my $cgi = shift;
	my $institution = $cgi->param('institution');
	my $sql = $cgi->dbh->prepare_cached('SELECT DISTINCT institution, catalog_number_1 as catalog_plate FROM image_catalog WHERE institution = ? ORDER BY CAST(catalog_number_1 as unsigned)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($institution);
	readResults($sql);
	return;
}

sub getInstitutionFragments {
	my $cgi = shift;
	my $institution = $cgi->param('institution');
	my $catalog_number_1 = $cgi->param('catalog_number_1');
	my $sql = $cgi->dbh->prepare_cached('SELECT catalog_number_2 as catalog_fragment, image_catalog_id FROM image_catalog WHERE institution = ? AND catalog_number_1 = ? AND catalog_side = 0 ORDER BY CAST(catalog_number_2 as unsigned)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($institution, $catalog_number_1);
	readResults($sql);
	return;
}

sub getInstitutionArtefacts {
	my $cgi = shift;
	my $catalog_id = $cgi->param('catalog_id');
	my $user_id = $cgi->param('user_id');
	my $sql = $cgi->dbh->prepare_cached('select distinct artefact.artefact_id, user_id from artefact join SQE_image on SQE_image.sqe_image_id = artefact.master_image_id join artefact_owner using(artefact_id) join scroll_version using(scroll_version_id) where SQE_image.image_catalog_id = ? and user_id = ?') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($catalog_id, $user_id);
	readResults($sql);
	return;
}

sub getScrollWidth {
	my $cgi = shift;
	my $scroll_id =  $cgi->param('scroll_id');
	my $scroll_version_id =  $cgi->param('scroll_version_id');
	my $sql = $cgi->dbh->prepare_cached('CALL getScrollWidth(?,?)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($scroll_id, $scroll_version_id);
	readResults($sql);
	return;
}

sub getScrollHeight {
	my $cgi = shift;
	my $scroll_id =  $cgi->param('scroll_id');
	my $scroll_version_id =  $cgi->param('scroll_version_id');
	my $sql = $cgi->dbh->prepare_cached('CALL getScrollHeight(?,?)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($scroll_id, $scroll_version_id);
	readResults($sql);
	return;
}

# First I copy the artefect to a new artefact owner with the currect scroll_version_id
# Then I change the scroll_id of the artefact to match the current scroll_id
sub addArtToComb {
	my $cgi = shift;
	my $art_id =  $cgi->param('art_id');
	my $scroll_id =  $cgi->param('scroll_id');
	my $scroll_version_id =  $cgi->param('version_id');
	$cgi->dbh->set_scrollversion($scroll_version_id);
	my $user_id = $cgi->dbh->user_id;

	my $sql = $cgi->dbh->prepare_cached('INSERT IGNORE INTO artefact_owner (artefact_id, scroll_version_id) VALUES(?,?)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
    $sql->execute($art_id, $scroll_version_id);
    $sql->finish;

	my ($new_scroll_data_id, $error) = $cgi->dbh->add_value("artefact", $art_id, "scroll_id", $scroll_id);
	handleDBError ($new_scroll_data_id, $error);
}

sub getScrollArtefacts {
	my $cgi = shift;
	my $scroll_id = $cgi->param('scroll_id');
	my $version_id = $cgi->param('scroll_version_id');
	my $sql = $cgi->dbh->prepare_cached('CALL getScrollVersionArtefacts(?, ?)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($scroll_id, $version_id);
	readResults($sql);
	return;
}

sub newCombination {
	my $cgi = shift;
	my $user_id = $cgi->dbh->user_id;
	my $name = $cgi->param('name'); 

	my $sql = $cgi->dbh->prepare_cached('INSERT INTO scroll () VALUES()') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute();
	my $scroll_id = $cgi->dbh->last_insert_id(undef, undef, undef, undef);

	$sql = $cgi->dbh->prepare_cached('INSERT INTO scroll_version (user_id, scroll_id, version) VALUES(?, ?, 0)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($user_id, $scroll_id);
	my $scroll_version_id = $cgi->dbh->last_insert_id(undef, undef, undef, undef);

	$sql = $cgi->dbh->prepare_cached('INSERT INTO scroll_data (name, scroll_id) VALUES(?, ?)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($name, $scroll_id);
	my $scroll_data_id = $cgi->dbh->last_insert_id(undef, undef, undef, undef);

	$sql = $cgi->dbh->prepare_cached('INSERT INTO scroll_data_owner (scroll_data_id, scroll_version_id) VALUES(?, ?)') 
		or die "Couldn't prepare statement: " . $cgi->dbh->errstr;
	$sql->execute($scroll_data_id, $scroll_version_id);

	print '{"created": {"scroll_data": ' . $scroll_data_id . ', "scroll_version":' . $scroll_version_id . '}}';
	return;
}

sub copyCombination {
	my $cgi = shift;
	my $scroll_id = $cgi->param('scroll_id');
	my $scroll_version_id = $cgi->param('scroll_version_id');
	$cgi->dbh->add_owner_to_scroll($scroll_id, $scroll_version_id);
	print '{"scroll_clone": "success"}';
	return;
}

sub nameCombination {
	my $cgi = shift;
	my $scroll_id = $cgi->param('scroll_id');
	my $scroll_data_id = $cgi->param('scroll_data_id');
	my $version_id = $cgi->param('version_id');
	my $scroll_name = $cgi->param('name');
	$cgi->dbh->set_scrollversion($version_id);
	my $user_id = $cgi->dbh->user_id;
	my ($new_scroll_data_id, $error) = $cgi->dbh->change_value("scroll_data", $scroll_data_id, "name", $scroll_name);
	handleDBError ($new_scroll_data_id, $error);
	return;
}

sub setArtPosition {
	my $cgi = shift;
	my $user_id = $cgi->dbh->user_id;
	my $scroll_id = $cgi->param('scroll_id');
	my $version_id = $cgi->param('version_id');
	$cgi->dbh->set_scrollversion($version_id);
	my $art_id = $cgi->param('art_id');
	my $x = $cgi->param('x');
	my $y = $cgi->param('y');
	my ($new_id, $error) = $cgi->dbh->change_value("artefact", $art_id, "position_in_scroll", ['POINT', $x, $y]);
	handleDBError ($new_id, $error);
	return;
}

sub setArtRotation {
	my $cgi = shift;
	my $user_id = $cgi->dbh->user_id;
	my $scroll_id = $cgi->param('scroll_id');
	my $version_id = $cgi->param('version_id');
	$cgi->dbh->set_scrollversion($version_id);
	my $art_id = $cgi->param('art_id');
	my $rotation = $cgi->param('rotation');
	my ($new_id, $error) = $cgi->dbh->change_value("artefact", $art_id, "rotation", $rotation);
	handleDBError ($new_id, $error);
	return;
}

processCGI();
