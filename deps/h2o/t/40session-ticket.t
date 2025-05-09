use strict;
use warnings;
use File::Temp qw(tempdir);
use Net::EmptyPort qw(check_port);
use Test::More;
use Time::HiRes qw(sleep);
use t::Util;

plan skip_all => "could not find openssl"
    unless prog_exists("openssl");
#plan skip_all => "openssl 1.0.2 or above is required"
#    unless `openssl version` =~ /^OpenSSL 1\.(?:0\.[2-9][^0-9]|[1-9])/s;

my $tempdir = tempdir(CLEANUP => 1);

subtest "internal" => sub {
    spawn_with(<< "EOT",
  mode: ticket
EOT
    sub {
        is test(), "New";
        test(); # openssl 0.9.8 seems to return "New" (maybe because in the first run we did not specify -sess_in)
        is test(), "Reused";
        is test(), "Reused";
    });
    spawn_with(<< "EOT",
  mode: ticket
EOT
    sub {
        is test(), "New";
    });
};

subtest "file" => sub {
    my $tickets_file = "t/40session-ticket/forever_ticket.yaml";
    spawn_with(<< "EOT",
  mode: ticket
  ticket-store: file
  ticket-file: $tickets_file
num-threads: 1
EOT
    sub {
        sleep 1; # wait for tickets file to be loaded
        is test(), "New";
        is test(), "Reused";
        is test(), "Reused";
    });
    spawn_with(<< "EOT",
  mode: ticket
  ticket-store: file
  ticket-file: $tickets_file
EOT
    sub {
        sleep 1; # wait for tickets file to be loaded
        is test(), "Reused";
    });
};

subtest "no-tickets-in-file" => sub {
    my $tickets_file = "t/40session-ticket/nonexistent";
    spawn_with(<< "EOT",
  mode: ticket
  ticket-store: file
  ticket-file: $tickets_file
num-threads: 1
EOT
    sub {
        is test(), "New";
        is test(), "New";
        is test(), "New";
    });
};

subtest "memcached" => sub {
    plan skip_all => "memcached not found"
        unless prog_exists("memcached");
    my $memc_port = empty_port();
    my $memc_user = getlogin || getpwuid($<);
    my $doit = sub {
        my $memc_proto = shift;
        my $memc_guard = spawn_server(
            argv     => [ qw(memcached -l 127.0.0.1 -p), $memc_port, "-B", $memc_proto, "-u", $memc_user ],
            is_ready => sub {
                check_port($memc_port);
            },
        );
        my $conf =<< "EOT";
  mode: ticket
  ticket-store: memcached
  memcached:
    host: 127.0.0.1
    port: $memc_port
    protocol: $memc_proto
num-threads: 1
EOT
        spawn_with($conf, sub {
            sleep 1;
            is test(), "New";
            sleep 0.5;
            is test(), "Reused";
            sleep 0.5;
            is test(), "Reused";
        });
        spawn_with($conf, sub {
            sleep 1;
            is test(), "Reused";
        });
    };
    $doit->("binary");
    $doit->("ascii");
};

my $server;

sub spawn_with {
    my ($opts, $cb) = @_;
    # FIXME server stalls if H3 is enabled and ticket encryption key cannot be read from file?
    $server = spawn_h2o({conf => << "EOT", disable_quic => 1});
ssl-session-resumption:
$opts
hosts:
  default:
    paths:
      /:
        file.dir: @{[ DOC_ROOT ]}
EOT
    $cb->();
}

sub test {
    my $cmd_opts = (-e "$tempdir/session" ? "-sess_in $tempdir/session" : "") . " -sess_out $tempdir/session";
    my $lines = run_openssl_client({ host => "127.0.0.1", port => $server->{tls_port}, opts => "$cmd_opts" });
    $lines =~ m{---\n(New|Reused),}s
        or die "failed to parse the output of s_client:{{{$lines}}}";
    $1;
}

undef $server;

done_testing;
