$VERSION = 0.00141;

###########################################################################
# Wiki::Gateway.pm:
#    Exposes a Wiki XML-RPC API for wikis which don't support it themselves
#
#  maintained by Bayle Shanks
#
# Copyright 2003 Bayle Shanks and L. M. Orchard. 
#
# Based on usemod_xmlrpc.cgi by l.m.orchard <deus_x@pobox.com> 
# http://www.decafbad.com
#
# also using some code by David Jacoby
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# You may also redistribute or modify it under the terms of Perl's Artistic
# License, at your option. 
#
###########################################################################

# API notes:
#  Each of these functions requires two more arguments than in the API.
#  They are $url and $type, and they precede all of the usual argument to each
#  fn. 
#
#  $url is the base URL of the wiki server that you are interfacing with, 
#  for example 
#    http://www.usemod.com/cgi-bin/mb.pl
#
#  $type is the type of the wiki server that you are interfacing with. Here
#  are the options:
#
#  * 'usemod1': UseMod 1.0
#  * 'Usemod1NoModwiki': close to UseMod 1.0, but without ModWiki



# NOTE: the 'moinmoin1' functions which send XMLRPC send it via the URL "$url/RecentChanges?action=xmlrpc",
# because some MoinMoins (like AtomWiki) don't like $url/?action=xmlrpc
#  so, moinmoin wikis which don't have a "RecentChanges" page may have a problem in the future (??? or will it work anyway)



package Wiki::Gateway;
# actually I'd like to see this as Wiki::WikiGatway eventually






## TODO: currently only getRecentChanges cares about "type". Everything else just assumes you are "usemod1".

###########################################################################
### Parameters
###########################################################################

### Set this if you are using the library as an XMLRPC web service
###   (the effect is only to encode some return values in an XMLRPC way)
my $XMLRPC = 0;

## "persistent" variables
## set by wikiGatewayTargetWiki
my $SERVER_URL;
my $SERVER_TYPE;


use strict;
#use Date::Parse;
use Date::Manip;
#use Time::Local;
#use LWP::Simple; # for some reason this has to be moved down below or it doesn't work as a web service

use XMLRPC::Lite;


sub setXMLRPC {
    $XMLRPC = @_[0];
}

##### new function, added by bayle
sub wikiGatewayTargetWiki {
# TODO: use "shift" to make the argument block more readable:
    my ($pkg, $url, $type);
    if ($XMLRPC) {
	($pkg, $url, $type) = @_;
    }
    else {
	($url, $type) = @_;
    }

    $SERVER_URL = $url;
    $SERVER_TYPE = $type;

#TODO: return this info if no args

}




###########################################################################
### Utility subroutines
###########################################################################

################################
# sub base64IfXMLRPC           #
################################
sub base64IfXMLRPC {
    if ($XMLRPC)
    {
	$SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
	use XMLRPC::Transport::HTTP;
	return SOAP::Data->type(base64 => @_[0]);
    }
    else {
	return @_[0];
    }
}


# input: date in UTC (iso 8601??) e.g. 20031112T08:04:15
# Actually, I'm having weird errors with Date::Parse, so I'm switching to Date::Manip.

#
# output: days from input until current time
sub dateToDays {
    my ($date) = @_;


#    print "DEBUG: $date\n";

#    my $requestedTime = str2time($date);
    my $requestedTime = UnixDate(ParseDate($date), "%s");
    #print "DEBUG2: $requestedTime\n";
    my $Now = UnixDate(ParseDate("now"),"%s");
    my $timeago = $Now - $requestedTime;
    my $daysago =  $timeago/(24*60*60);

#    die "i died\n";
#    use Data::Dumper;
#    die Dumper($daysago);

    return $daysago;

}

#######
# input: integer $daysAgo
# output: now - $daysAgo, returned as format 20031112T08:04:15, and converted from local timezone to UTC (+0000)
#######
sub daysAgoToDate {
    my ($daysAgo) = @_;

    my $secondsAgo = $daysAgo*(24*60*60);
    my $date= time() - $secondsAgo;
    #print "DEBUG3: $date\n";
    $date = ParseDateString('epoch ' . $date); # convert into Date::Manip format
    $date = Date_ConvTZ($date,"",'+0000');     # convert to UTC timezone
    return UnixDate($date, '%Q') . 'T' . UnixDate($date, '%H:%M:%S');
        # format result like 20031112T08:04:15
}

###########################################################################
### Wiki XML-RPC API Methods
###########################################################################

###########################################################################
# * array getRecentChanges ( Date timestamp ):
#      Get list of changed pages since timestamp, which should be in
#      UTC. The result is an array, where each element is a struct:
#         * name (string) :
#              Name of the page. The name is UTF-8 with URL encoding
#              to make it ASCII.
#         * lastModified (date) :
#              Date of last modification, in UTC.
#         * author (string) :
#              Name of the author (if available). Again, name is
#              UTF-8 with URL encoding.
#         * version (int) :
#              Current version.
###########################################################################




################################
# sub getRC_ModWiki            #
################################

sub getRC_ModWiki {
######  used if the wiki server supports ModWiki
    my ($pkg, $url, $type, $date);
#    if ($XMLRPC) {
#	($pkg, $date) = @_;
#	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
#    }
#    else {
	($url, $type, $date) = @_;
#    }
##################
# INIT
##################


    use LWP::Simple; 

    if ($XMLRPC)
    {
	$SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
	use XMLRPC::Transport::HTTP;
    }

    use XML::RSS;


    my $MODWIKI_URI = 'http://purl.org/rss/1.0/modules/wiki/';
    my @changes = ();

    
##################
# FETCH RSS FROM WIKI SERVER  
##################


    my $URL = $url;
    my $rssString = get $URL;
  
# this kludge added b/c of an apparent bug in 
# some (older?) versions of MoinMoin:  
    $rssString =~ s/xmlns:None/xmlns/g;


##################
# PARSE RSS   
##################
    
    my $rss = new XML::RSS;
    $rss->add_module(prefix=>'modwiki', uri=>'http://purl.org/rss/1.0/modules/wiki/');

# do I need to add dc?
#    $rss->add_module(prefix=>'modwiki', uri=>'http://purl.org/rss/1.0/modules/wiki/');
    $rss->parse($rssString);
    


##################
# ITERATE THROUGH EACH RSS ITEM, 
# AND STORE THE RELEVANT FIELDS INTO RETURN STRUCT   
##################
# notes:
#  not sure if this is the right date format...
#  why didn't this work:
#		   author       => $item->{dc}->{'contributor'},
#  i also added an 'importance' field here

    foreach my $item (@{$rss->{'items'}}) {
	my $pageinfo =
	{
		name         => $item->{'title'},
		author       => $item->{'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}->{'value'},
		lastModified => $item->{dc}->{'date'},
		comment       => $item->{'description'}, 
		version      => $item->{$MODWIKI_URI}->{'version'},
		importance => $item->{$MODWIKI_URI}->{'importance'},
		#debug => $item
	    };
  

##### Special encoding for xmlrpc
	if ($XMLRPC)
	{
	    $pageinfo->{lastModified} = SOAP::Data->type(dateTime => ($pageinfo->{lastModified}));  
	}
	
	push @changes, $pageinfo;      
    }
    
    return \@changes;
}


################################
# sub getRC_Usemod1NoModwiki   #
################################

sub getRC_Usemod1NoModwiki
{
    ##### called if the wiki type passed in is "usemod1NoModWiki"
    ##### a screen-scraping alternative for UseMod
    #####  (probably is or can be adapted to be compatible with pre-1.0 UseMod
    #####   which usually does not support RSS)

    ##### this fn was based on David Jacoby's code
    my ($pkg, $url, $type, $date);
    if ($XMLRPC) {
	($pkg, $date) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $date) = @_;
    }

##################
# THIS IS WRONG
##################
	my $days = dateToDays($date);  

##################
# INIT
##################
#	my $time = str2time($date);
    my $time = UnixDate(ParseDate($date), "%s");
	my @changes = ();
	my $pagename;
	my $comment;
	my ($author, $authorID, $authorIP);

##################
# FETCH RSS FROM WIKI SERVER  
##################
	my $URL = $url."?action=rc&days=$days";
	my $rcPage = get $URL;


##################
# FIND THE LINES WITH THE CHANGES ON THEM  
##################

### split into lines

	my @output = split /\n/ , $rcPage ;
	@output = grep /^<li>/ , @output ;


####### filter for only the lines with the actual changes on them 
	my @secondary_output;

	for my $line ( @output ) {
	    next if $line !~ /^<li>/ ;
	    next if $line !~ /diff/ ;
	    push @secondary_output , $line ;
	}

	@output = @secondary_output ;

##################
# ITERATE OVER THE CHANGE LINES AND PROCESS THEM  
##################

# notes:
# David used to have this code in here:
#     $line    =~ /(<a href="([^?]*?\?([A-Za-z0-9=&]+))">)/ ; 
# (perhaps that will be needed for older version of UseMod?)

	for my $line ( @output ) {
	    next if $line !~ /^<li>/ ;

  #### parse pagename
  ####
	    $line    =~ /(<a href="([^?]*?\?action=browse&.*?&id=([A-Za-z0-9]+))">)/ ; 
	    my $anchor   = $1 ;
	    my $link     = $2 ; 
	    my $pagename = $3 ;

  #### parse comment field
  ####
	    $line       =~ /strong>\[([^<]+)\]<\/strong/ ;
	    my $comment = $1 ;
	    $comment    = undef if $comment eq $anchor ;

  #### parse author 
  ####
  
    # when the user is logged in, UseMod displays the author's username
    #  but it also has a popup with their ID# and IP
    # when the user is not logged in, UseMod displays the IP in the author slot

	    $line =~ / \. \. \. \. \. (.*)/;
	    $author = $1;
	    my $regexp = '<a href="[^"]*" title="ID (.*?) from ([^"]*)">([^>]*)<\/a>';
	    if ($author =~ /$regexp/)
	    {
		$authorID = $1;
		$authorIP = $2;
		$author = $3;
	    }
	    else {
		$authorIP = $author;
	    }
	    

# TODO: implement time handling
###   this code (from Orchard) might be useful when doing so

	    my ($sec, $min, $hr, $dd, $mm, $yy, $wd, $yd, $isdst) =
		localtime($time);
	    $yy += 1900; $mm++;
	    my $last_modified = sprintf('%04d%02d%02dT%02d:%02d:%02d',
					$yy,$mm,$dd,$hr,$min,$sec);


##################
# STORE INFO INTO RETURN STRUCT  
##################


## is there no comment field in the previous version of WikiXmlRpcInterface ?!? 
## well, i'm adding it

# TODO:
#      lastModified => SOAP::Data->type(dateTime => $last_modified),
#      version      => 1 # version not implemented yet
	    my $pageinfo =
	    {
		name         => qq($pagename),
		author       => qq($author),
		comment       => qq($comment), 
	    };
  
	    push @changes, $pageinfo;
	    
	}

	return \@changes;

}


################################
# sub getRecentChanges   #
################################
sub getRecentChanges {

    my ($pkg, $url, $type, $date);
    if ($XMLRPC) {
	($pkg, $date) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $date) = @_;
    }


#    print "DEBUG: $url\n$type\n$date\n";

	#### Dispatches based on $type, the type of the wiki server

# note that I left out the "last SWITCH;"s here
      SWITCH: {
	  if ($type eq "usemod1")          {
	      my $time = UnixDate(ParseDate($date), "%s");
	      my $days = dateToDays($date);

	      return getRC_ModWiki($url . "?action=rss&days=$days", $type, $date);
	  }
	  if ($type eq "moinmoin1_ModWiki" || $type eq "moinmoin1") {
	      #moinmoin currently has a bug in its XMLRPC getRecentChanges
	      return getRC_ModWiki($url . "RecentChanges?action=rss_rc&items=100", $type, $date);

	  }
	  if ($type eq "usemod1NoModWiki") {return getRC_Usemod1NoModwiki(@_);}
	  if ($type eq "moinmoin1")        {return XMLRPC::Lite
	      # moinmoin currently has a bug in its XMLRPC getRecentChanges
	      # so this will be handled by "moinmoin1_ModWiki"
						-> proxy("${url}RecentChanges?action=xmlrpc2")
						-> call('getRecentChanges',$date)
						-> result;}
	  if ($type eq "moinmoin1Straight")        {return XMLRPC::Lite
						-> proxy("$url?action=xmlrpc")
						-> call('getRecentChanges',$date)
						-> result;}
      }
}


###########################################################################
# * int getRPCVersionSupported():
#      Returns 1 with this version of the Wiki API.
###########################################################################

sub getRPCVersionSupported {
	return 1;
}

###########################################################################
# * base64 getPage( String pagename ):
#     Get the raw Wiki text of page, latest version. Page name must be
#     UTF-8, with URL encoding. Returned value is a binary object,
#     with UTF-8 encoded page data.
###########################################################################

sub getPage {
    my ($pkg, $url, $type, $pagename);
    if ($XMLRPC) {
	($pkg, $pagename) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('getPage',$pagename)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {

	  use LWP::Simple;
	  my $pagetext = get $url."?action=browse&id=$pagename&raw=1"; 

	  return base64IfXMLRPC($pagetext);
      }
  }
}

###########################################################################
#  * base64 getPageVersion( String pagename, int version ):
#     Get the raw Wiki text of page. Returns UTF-8, expects UTF-8 with
#     URL encoding.
###########################################################################

sub getPageVersion {
    my ($pkg, $url, $type, $pagename, $version);
    if ($XMLRPC) {
	($pkg, $pagename, $version) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename, $version) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('getPageVersion',$pagename,$version)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {

	  use LWP::Simple;
	  my $pagetext = get $url."?action=browse&id=$pagename&revision=version&raw=1"; 

	  return base64IfXMLRPC($pagetext);

      }
  }
}

###########################################################################
#  * base64 getPageHTML( String pagename ):
#      Return page in rendered HTML. Returns UTF-8, expects UTF-8 with
#      URL encoding.
###########################################################################

sub getPageHTML {
    my ($pkg, $url, $type, $pagename);
    if ($XMLRPC) {
	($pkg, $pagename) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('getPageHTML',$pagename)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {

	  use LWP::Simple;
	  my $pagetext = get $url."?action=browse&id=$pagename&embed=1"; 

	  return base64IfXMLRPC($pagetext);
      }
  }
}

###########################################################################
#  * base64 getPageHTMLVersion( String pagename, int version ):
#      Return page in rendered HTML, UTF-8.
###########################################################################

sub getPageHTMLVersion {
    my ($pkg, $url, $type, $pagename, $version);
    if ($XMLRPC) {
	($pkg, $pagename, $version) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename, $version) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('getPageHTMLVersion',$pagename,$version)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {
	  use LWP::Simple;
	  my $pagetext = get $url."?action=browse&id=$pagename&version=$version&embed=1"; 
    
	  return base64IfXMLRPC($pagetext);
      }
  }
}

###########################################################################
#  * array getAllPages():
#      Returns a list of all pages. The result is an array of strings,
#      again UTF-8 in URL encoding.
###########################################################################

sub getAllPages {
    my ($pkg, $url, $type);
    if ($XMLRPC) {
	($pkg) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type) = @_;
    }

      SWITCH: {
	  if ($type eq "moinmoin1")        {return XMLRPC::Lite
						-> proxy("${url}RecentChanges?action=xmlrpc")
						-> call('getAllPages')
						-> result;}
	  if ($type eq "moinmoin1Straight")        {return XMLRPC::Lite
						-> proxy("$url?action=xmlrpc")
						-> call('getAllPages')
						-> result;}

	  if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
	  {
      
	      #### FETCH PAGE FROM WIKI SERVER
	      use LWP::Simple;
	      my $index = get $url.'?action=index&embed=1';

	      #### CUT OFF HEADER AND FOOTER
	      $index =~ /.*pages found:<\/h2>(.*)<hr .*/is;
	      # maybe it would be less brittle to grep for the "FORM" ?
	      $index = $1;

	      #### PROCESS THE REST
	      $index =~ s/.... <a href="/<a href="/gi;
	      $index =~ s/<a href="[^>]*>(.*)<\/a>/$1/gi;
    $index =~ s/\n//g;
    my @lines = split /<br>/,$index;

    return \@lines;
}
}
}

###########################################################################
#  * struct getPageInfo( string pagename ) :
#      returns a struct with elements
#          * name (string): the canonical page name, URL-encoded UTF-8.
#          * lastModified (date): Last modification date, UTC.
#          * author (string): author name, URL-encoded UTF-8.
#          * version (int): current version
###########################################################################
##### NOT IMPLEMENTED YET
###########################################################################

sub getPageInfo {
    my ($pkg, $url, $type, $pagename);
    if ($XMLRPC) {
	($pkg, $pagename) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('getPageInfo',$pagename)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {
	  {

# here's what was in Orchard's code:
#	my ($meta, $pagetext);
#	my $pageinfo = {};

#		return
#		  {
#		   name         => $pagename,
#		   lastModified => SOAP::Data->type(dateTime => $last_modified),#		   author       => $extra{name} || $host,
#		   version      => $extra{revision}
#		  };
#	}
	      return {};
	  }
      }
  }
}

###########################################################################
#  * struct getPageInfoVersion( string pagename, int version ) :
#      returns a struct just like plain getPageInfo(), but this time
#      for a specific version.
###########################################################################
##### NOT IMPLEMENTED YET
###########################################################################

sub getPageInfoVersion {
    my ($pkg, $url, $type, $pagename, $version);
    if ($XMLRPC) {
	($pkg, $pagename, $version) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename, $version) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('getPageInfoVersion',$pagename,$version)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {

#see getPageInfo for something close to what Orchard had here
	return {};
    }
  }
}

###########################################################################
###	    * array listLinks( string pagename ): Lists all links for a given
###        page. The returned array contains structs, with the following
###        elements
###          * name (string) : The page name or URL the link is to.
###          * type (int) : The link type. Zero (0) for internal Wiki
###             link, one (1) for external link (URL - image link,
###             whatever).
###########################################################################
##### NOT IMPLEMENTED YET
###########################################################################
sub listLinks {
    my ($pkg, $url, $type, $pagename);
    if ($XMLRPC) {
	($pkg, $pagename) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename) = @_;
    }
#is this just for outgoing links? why do we need this?
# bayle: i think there should also be something to get the "full link list" and the reverse links

  SWITCH: {
      if ($type eq "moinmoin1")        {return XMLRPC::Lite
					    -> proxy("${url}RecentChanges?action=xmlrpc")
					    -> call('listLinks',$pagename)
					    -> result;}
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {

#see getPageInfo for something close to what Orchard had here



# here's what orchard had:
#	my @int_links = &UseModWiki::GetPageLinks($pagename, 1, 0, 0);
#	my @ext_links = &UseModWiki::GetPageLinks($pagename, 0, 1, 1);

#	my @links_out;
#	push @links_out, map { {name => $_, type => 0} } @int_links;
#	push @links_out, map { {name => $_, type => 1} } @ext_links;
	
#	return \@links_out;

      }
  }
}




###########################################################################
### * boolean wiki.putPage( String pagename, base64 text ): Set the
###    text of a page, returning true on success
###########################################################################

sub putPage_moinmoin1 {
    my ($url, $type, $pagename, $pagetext, $cookiejar) = @_;

# NOTE: if you pass in something other than a scalar for $pagetext, you'll get \a wierd error! I got "Not an ARRAY reference at /usr/share/perl5/URI/_query.pm \line".

    my ($req, $res);

##################
# INIT
##################
	use LWP::Simple;
	use HTML::Form;
	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);
        if ($cookiejar) {$ua->cookie_jar($cookiejar);}


##################
# FETCH POST FORM FROM WIKI SERVER
##################
    my $URL = $url.$pagename.'?action=edit';	
    $req = HTTP::Request->new(GET => $URL);
    $res = $ua->request($req);
    my $writeFormPage = $res->content;


##################
# FILL IN THE FORM
##################
    
	my $form = HTML::Form->parse($writeFormPage, $res->base());
	defined($form) or return "Can't even get wiki edit form at $URL";
    if ($form->find_input('savetext')) {
	$form->value('savetext',$pagetext);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($writeFormPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'savetext' control found in edit form (while using 'moinmoin1' protocol for communicating with wiki)";
    }

#### to create a fake edit conflict for testing purposes, uncomment this line
#### and then edit something from a different IP and username immediately
#### before running this method
#	$form->value('oldtime',0);



##################
# SUBMIT IT
##################
	my $req = $form->click('button_save');
	my $res = $ua->request($req);





##################
# CHECK FOR EDIT CONFLICT
##################

### NOT IMPLEMENTED FOR MOINMOIN YET

	if ($res->as_string =~ /<H1>Edit Conflict!<\/H1>/i)
	{
	    return "edit conflict";
	}

	if (!($res->is_redirect))
	{
	    ### if there is no edit conflict, UseMod returns a redirect.
	    ### so maybe if we reach this point, something is wrong and we
	    ###    should fail and report and unknown problem.
	    ### i dunno.

#	    return "not redirect";
	}


    my $moinmoinMessage;
    $res->content =~ /<div id="message">\s*<p>(.*?)<\/p>/; 
	{
	    $moinmoinMessage  = $1;
	    if (! (
		   ($moinmoinMessage =~ /Thank you for your changes/)
		   || ($moinmoinMessage =~ /You did not change the page content, not saved/)
		   )) {
		return $moinmoinMessage;
	    } 
	}


	
#todo: error checking
# how else would you do error checking? UseMod doesn't give you a clear
# "success" indicator, unless you want to check the changed page to make
# sure your text is there (but what if someone else changed the page in the meantime?)





	if ($@) { return $@; }

#    print STDERR "success on $url, $pagename, $pagetext\n";

	if ($XMLRPC)
	{
	    $SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
	    use XMLRPC::Transport::HTTP;
	    return SOAP::Data->type(boolean => 1);
	}
	else {
	    return 1;
	}

    
}




sub putPage {
    my ($pkg, $url, $type, $pagename, $pagetext, $cookiejar);
    if ($XMLRPC) {
	($pkg, $pagename, $pagetext, $cookiejar) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $pagename, $pagetext, $cookiejar) = @_;
    }

  SWITCH: {
#      if ($type eq "xmlrpc")        {return XMLRPC::Lite
#					    -> proxy("${url}RecentChanges?action=xmlrpc")
#					    -> call('putPage',$pagename, $pagetext)
#					    -> result;}
      if ($type eq "moinmoin1")        {
	  return putPage_moinmoin1($url, $type, $pagename, $pagetext, $cookiejar);
      }
      if (($type eq "usemod1") || ($type eq "usemod1NoModWiki")) 
      {

##################
# INIT
##################
	use LWP::Simple;
	use HTML::Form;
	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);

##################
# FETCH POST FORM FROM WIKI SERVER
##################
	my $URL = $url.'?action=edit&id='.$pagename;	
	my $writeFormPage = get $URL;

##################
# FILL IN THE FORM
##################
	my $form = HTML::Form->parse($writeFormPage, $URL);
	defined($form) or return "Can't even get wiki edit form at $URL";
	$form->value('text',$pagetext);

#### to create a fake edit conflict for testing purposes, uncomment this line
#### and then edit something from a different IP and username immediately
#### before running this method
#	$form->value('oldtime',0);

##################
# SUBMIT IT
##################
	my $req = $form->click('Save');
	my $res = $ua->request($req);

##################
# CHECK FOR EDIT CONFLICT
##################
	if ($res->as_string =~ /<H1>Edit Conflict!<\/H1>/i)
	{
	    return "edit conflict";
	}

	if (!($res->is_redirect))
	{
	    ### if there is no edit conflict, UseMod returns a redirect.
	    ### so maybe if we reach this point, something is wrong and we
	    ###    should fail and report and unknown problem.
	    ### i dunno.

#	    return "not redirect";
	}
	
#todo: error checking
# how else would you do error checking? UseMod doesn't give you a clear
# "success" indicator, unless you want to check the changed page to make
# sure your text is there (but what if someone else changed the page in the meantime?)

	if ($@) { return $@; }

	if ($XMLRPC)
	{
	    $SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
	    use XMLRPC::Transport::HTTP;
	    return SOAP::Data->type(boolean => 1);
	}
	else {
	    return 1;
	}

    }
  }

}


sub login {
    my ($pkg, $url, $type, $username, $password, $cookiejar);
    if ($XMLRPC) {
	($pkg, $username, $password, $cookiejar) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $username, $password, $cookiejar) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {
	  return login_moinmoin1($url, $type, $username, $password, $cookiejar);
      }
    

  }
}

sub findMoinMoinMessageInPage {
    my ($page) = @_;

    my $moinmoinMessage;
    if ($page =~ /<div id="message">\s*<p>(.*?)<\/p>/)  
      {$moinmoinMessage  = $1; }
    
    return $moinmoinMessage;
}


sub login_moinmoin1 {
    my ($url, $type, $username, $password, $cookiejar) = @_;

    my ($req, $res);

##################
# INIT
##################
	use LWP::Simple;
	use HTML::Form;
	use LWP::UserAgent;
    use HTTP::Cookies;

	my $ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);
        if ($cookiejar) {$ua->cookie_jar($cookiejar);}
    else {
#	print STDERR "Creating new cookie jar\n";
	$cookiejar = HTTP::Cookies->new();
	$ua->cookie_jar($cookiejar);
#	print "ere it is: $cookiejar";
    }

##################
# FETCH POST FORM FROM WIKI SERVER
##################
    my $URL = $url.'UserPreferences';
    $req = HTTP::Request->new(GET => $URL);
    $res = $ua->request($req);
    my $userPrefPage = $res->content;


##################
# FILL IN THE FORM
##################

    my $form = HTML::Form->parse($userPrefPage, $res->base());
    defined($form) or return "Can't even get User Preferences form at $URL";

    if ($form->find_input('username')) {
	$form->value('username',$username);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($userPrefPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'username' control found in User Preferences form (while using 'moinmoin1' protocol for communicating with wiki)";
    }

    if ($form->find_input('password')) {
	$form->value('password',$password);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($userPrefPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'password' control found in User Preferences form (while using 'moinmoin1' protocol for communicating with wiki)";
    }






##################
# SUBMIT IT
##################
	my $req = $form->click('login');
	my $res = $ua->request($req);


##### check if accepted
    if ($res->content =~ /Unknown user name or password/) {
	return "Unknown user name or password";
    }
	
#todo: error checking
# how else would you do error checking? UseMod doesn't give you a clear
# "success" indicator, unless you want to check the changed page to make
# sure your text is there (but what if someone else changed the page in the meantime?)

	if ($@) { return $@; }

	if ($XMLRPC)
	{
	    $SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
	    use XMLRPC::Transport::HTTP;
#	    return SOAP::Data->type(boolean => 1);
	    return $ua->cookie_jar;
	}
	else {
	    return $ua->cookie_jar;
	}

    
}



sub createNewUser {
    my ($pkg, $url, $type, $username, $password, $email, $cookiejar);
    if ($XMLRPC) {
	($pkg, $username, $password, $email, $cookiejar) = @_;
	($url, $type) = ($SERVER_URL, $SERVER_TYPE); 
    }
    else {
	($url, $type, $username, $password, $email, $cookiejar) = @_;
    }

  SWITCH: {
      if ($type eq "moinmoin1")        {
	  return createNewUser_moinmoin1($url, $type, $username, $password, $email, $cookiejar);
      }
  }
}

sub createNewUser_moinmoin1 {
    my ($url, $type, $username, $password, $email, $cookiejar) = @_;

    my ($req, $res);

##################
# INIT
##################
	use LWP::Simple;
	use HTML::Form;
	use LWP::UserAgent;
    use HTTP::Cookies;

	my $ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);
        if ($cookiejar) {$ua->cookie_jar($cookiejar);}
    else {
#	print STDERR "Creating new cookie jar\n";
	$cookiejar = HTTP::Cookies->new();
	$ua->cookie_jar($cookiejar);
#	print "ere it is: $cookiejar";
    }

##################
# FETCH POST FORM FROM WIKI SERVER
##################
    my $URL = $url.'UserPreferences';
    $req = HTTP::Request->new(GET => $URL);
    $res = $ua->request($req);
    my $userPrefPage = $res->content;


##################
# FILL IN THE FORM
##################

    my $form = HTML::Form->parse($userPrefPage, $res->base());
    defined($form) or return "Can't even get User Preferences form at $URL";

    if ($form->find_input('username')) {
	$form->value('username',$username);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($userPrefPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'username' control found in User Preferences form (while using 'moinmoin1' protocol for communicating with wiki)";
    }

    if ($form->find_input('password')) {
	$form->value('password',$password);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($userPrefPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'password' control found in User Preferences form (while using 'moinmoin1' protocol for communicating with wiki)";
    }

    if ($form->find_input('password2')) {
	$form->value('password2',$password);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($userPrefPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'password2' control found in User Preferences form (while using 'moinmoin1' protocol for communicating with wiki)";
    }

    if ($form->find_input('email')) {
	$form->value('email',$email);
    }
    else {
	my $msg; 
	$msg = findMoinMoinMessageInPage($userPrefPage); 
	if ($msg) {return $msg;}
	
	return "WikiGateway error: No 'email' control found in User Preferences form (while using 'moinmoin1' protocol for communicating with wiki)";
    }







##################
# SUBMIT IT
##################
	my $req = $form->click('save');
	my $res = $ua->request($req);


##### check if accepted

    my $moinmoinMessage;
    $res->content =~ /<div id="message">\s*<p>(.*?)<\/p>/; 
	{
	    $moinmoinMessage  = $1;
	    if (! ($moinmoinMessage =~ /User preferences saved!/)) {
		return $moinmoinMessage;
	    } 
	}

	
#todo: error checking
# how else would you do error checking? UseMod doesn't give you a clear
# "success" indicator, unless you want to check the changed page to make
# sure your text is there (but what if someone else changed the page in the meantime?)

	if ($@) { return $@; }

	if ($XMLRPC)
	{
	    $SOAP::Constants::DO_NOT_USE_XML_PARSER = 1;
	    use XMLRPC::Transport::HTTP;
#	    return SOAP::Data->type(boolean => 1);
	    return $ua->cookie_jar;
	}
	else {
	    return $ua->cookie_jar;
	}

    
}



BEGIN {
    use Exporter   ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    my @LIST_OF_ALL_WIKIGATEWAY_API_SUBROUTINES = qw(&getRecentChanges &getRPCVersionSupported &getPage &getPageHTML &getPageHTMLVersion &getAllPages &getPageInfo &getPageInfoVersion &listLinks &putPage);

    # set the version for version checking
    $VERSION     = .001;
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( 
                     ALL => 
                       \@LIST_OF_ALL_WIKIGATEWAY_API_SUBROUTINES
                     );    

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = @LIST_OF_ALL_WIKIGATEWAY_API_SUBROUTINES;
}
our @EXPORT_OK;


1;
