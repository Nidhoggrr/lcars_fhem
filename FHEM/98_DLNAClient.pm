##############################################
# 2014-01-28 hokascha $
#
#  DLNA Module to play given URLs on a DLNA Renderer
#
##############################################
package main;

use strict;
use warnings;
use Net::UPnP::ControlPoint;
use Net::UPnP::AV::MediaRenderer;
use Net::UPnP::ActionResponse;
use Net::UPnP::AV::MediaServer;
use Data::Dumper;

sub
DLNAClient_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "dlna_Set";
  $hash->{DefFn}     = "dlna_Define";
  $hash->{AttrList}  = "server file";
}

##################################
sub
dlna_Set($@)
{
	my ($hash, @a) = @_;
	my $TVname = shift @a;
	my $stopbeforeplay=0;
	return "no set value specified" if(int(@a) < 1);
	return "Unknown argument, choose one of on off play stop <url>" if($a[0] eq "?");
	my $v = join(" ", @a);
	Log3 $hash, 3, "DLNAClient set $TVname $v";
	$TVname = $hash->{CLIENTNAME};
	if (not (defined $hash->{DEV})) {$hash->{DEV}=find_renderer_by_name($hash);};
	my $dev = $hash->{DEV};
	  
	my $renderer = Net::UPnP::AV::MediaRenderer->new();
	$renderer->setdevice($dev);
	my $condir_service = $dev->getservicebyname('urn:schemas-upnp-org:service:AVTransport:1');
	my %action_in_arg = (
		'ObjectID' => 0,
		'InstanceID' => '0'
	    );
	my $action_res = $condir_service->postcontrol('GetTransportInfo', \%action_in_arg);
	my $actrion_out_arg = $action_res->getargumentlist();
	#Log3 $hash, 3, "DLNAClient: ".Dumper($actrion_out_arg);
	my $x = $actrion_out_arg->{'CurrentTransportState'};
	Log3 $hash, 3, "DLNAClient: Device current state is <<$x>>. ";
	if ( ($x !~ /PLAY/) || ($stopbeforeplay == 1) ) { 
		if ($stopbeforeplay == 1) { 
			Log3 $hash, 3, "DLNAClient: First run, force stop-start ";
			$renderer->stop();
		} else {  
			Log3 $hash, 3, "DLNAClient: Device (" . $dev->getfriendlyname() . ") is in bad state, starting up! "; 
		}
	} else {
		#Log3 $hash, 3,  "This is ok, skipping.";
		#next;
	}

	if($a[0] eq "off" || $a[0] eq "stop" ){
		 $renderer->stop();
		 readingsSingleUpdate($hash,"state",$v,1);
		return undef;
	}
	if($a[0] eq "on" || $a[0] eq "play"){
		 $renderer->play();
		 readingsSingleUpdate($hash,"state",$v,1);
		return undef;
	}

	my $file = $v;
#	my $meta = <<EOF;
#&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;&lt;item id=&quot;2\$8\$1B&quot; parentID=&quot;2\$15&quot; restricted=&quot;true&quot;&gt;  &lt;dc:title&gt;final_movie&lt;/dc:title&gt;  &lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;  &lt;res protocolInfo=&quot;http-get:*:video/x-msvideo:*&quot; size=&quot;138332664&quot; duration=&quot;2:35:27.079&quot; resolution=&quot;1366x768&quot; bitrate=&quot;6002933&quot; sampleFrequency=&quot;44100&quot; nrAudioChannels=&quot;1&quot;&gt;$file&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;
#EOF
	my $id = 0;
	#$renderer->setAVTransportURI(InstanceID => $id, CurrentURI => $file, CurrentURIMetaData => $meta);

	$renderer->setAVTransportURI(CurrentURI => $file);
	if ($stopbeforeplay == 1) {
	   $renderer->stop();
	   $stopbeforeplay = 0;
	}

	$renderer->play(); 

	readingsSingleUpdate($hash,"state",$v,1);
	return undef;
}

sub
dlna_Define($$)
{
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);

	return "Wrong syntax: use define <name> DLNAClient <Name>" if(int(@a) != 3);
	my $name       = shift @a;
	my $type       = shift @a;
	my $clientName        = shift @a;
	$hash->{CLIENTNAME}     = $clientName;
	$hash->{DEV} = find_renderer_by_name($hash);
	return undef;
}

sub
find_renderer_by_name($)
{
	my ($hash) = @_;
	my  $clientName = $hash->{CLIENTNAME};
	my $obj = Net::UPnP::ControlPoint->new();
	my @dev_list = ();
	my $retry_cnt = 0;
	while (@dev_list <= 0 ) {
	Log3 $hash, 3,  "DLNAClient: Searching for renderers... @dev_list";
	@dev_list = $obj->search(st =>'urn:schemas-upnp-org:device:MediaRenderer:1', mx => 5);
	$retry_cnt++;
	if ($retry_cnt >= 5) {
		Log3 $hash, 3, "DLNAClient: [!] No renderers found. Exiting.";
		return undef;
		}
	}

	my $devNum= 0;
	my $dev;
	foreach $dev (@dev_list) {
	my $device_type = $dev->getdevicetype();
	if  ($device_type ne 'urn:schemas-upnp-org:device:MediaRenderer:1') {
	    next;
	}
	$devNum++;
	my $friendlyname = $dev->getfriendlyname(); 
	Log3 $hash, 3, "DLNAClient: found [$devNum] : device name: [" . $friendlyname . "] " ;
	if ($friendlyname !~ /$clientName/) {  Log3 $hash, 3,  "DLNAClient: skipping this device.";next;}
		#$hash->{DEV} = $dev;
		#readingsSingleUpdate($hash,"dev",$dev,0);
		Log3 $hash, 3, "DLNA Client selected: [" . $friendlyname . "] [" . $dev ."] [". $dev->getmodelurl()."]";
		return $dev;
	}
	return undef
}


1;

=pod
=begin html

<a name="DLNAClient"></a>
<h3>DLNAClient</h3>
<ul>

  Define a DLNA client. A DLNA client can take an URL to play via <a href="#set">set</a>.
  
  <br><br>

  <a name="DLNAClientdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; DLNAClient &lt;regex&gt;</code>
    <br><br>

    Example:
    <ul>
      <code>define MyPlayer DLNAClient NP2500</code><br>
      Here, NP2500 is part of the name of the player as it announces itself to the network.<br/>
      <code>set MyPlayer http://link-to-my/file.mp3</code><br>
    </ul>
  </ul>
  <br>

  <a name="DLNAClientset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt</code><br>
    Set any URL to play.
  </ul>
  <br>

  <a name="DLNAClientget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="DLNAClientattr"></a>
  <b>Attributes</b>
  <ul>
    <li>server<br>
	NOT YET IMPLEMENTED - Name of DLNA Server library to search for given filename
	</li>
    
  </ul>
  <br>

</ul>

=end html
=cut
