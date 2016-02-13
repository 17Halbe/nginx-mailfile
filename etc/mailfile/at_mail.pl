#!/usr/bin/perl

my $LOG_FILE = "/var/mail/vmail/script.log";
open my $log, ">", $LOG_FILE or die("Could not open file. $!");
#my $user_address = @ARGV[0];
#my $content = @ARGV[1];

my ($to, $subject, $body_file) = @ARGV;
my $from = 'downloads@gar-nich.net';
#my $subject = "Datei wird in einer Woche gelöscht";
open my $file, "<", $body_file or die("ould not open file. $!");
my $content = do { local $/; <$file> }; #read the whole file into mail_body
close $file;
print $log "Mail to $to: $subject Content: $content\n";
open(MAIL, "|/usr/sbin/sendmail -t");
# Email Header
print MAIL "To: $to\n";
print MAIL "From: $from\n";
print MAIL "Subject: $subject\n\n";
# Email Body
print MAIL $content;
close(MAIL);
print $log "Mail sent\n";


