#!/bin/perl

use strict;
use 5;

use Text::Markdown 'markdown';
use Text::Xslate 'mark_raw';
use Getopt::Long;
use YAML;
use Data::Dumper;
use Unicode::Normalize;
use Text::Unidecode;

my $post_dir = "test";
my $out_dir = "docs";
my $post_template = "post.html";
my $issue_template = "issue.html";
my $include_path = "tl";
my $title = "Title";

GetOptions(
    "dir=s" => \$post_dir,
    "out=s" => \$out_dir,
    "post-tl=s" => \$post_template,
    "issue-tl=s" => \$issue_template,
    "include=s" => \$include_path,
    "title=s" => \$title,
    );

my $tl = Text::Xslate->new(path => ($include_path),
                           cache => 0);

# copied from stack overflow ;)
sub slugify {
    my ($input) = @_;

    $input = NFC($input);          # Normalize (recompose) the Unicode string
    $input = unidecode($input);    # Convert non-ASCII characters to closest equivalents
    $input =~ s/[^\w\s-]//g;       # Remove all characters that are not word characters (includes _), spaces, or hyphens
    $input =~ s/^\s+|\s+$//g;      # Trim whitespace from both ends
    $input = lc($input);
    $input =~ s/[-\s]+/-/g;        # Replace all occurrences of spaces and hyphens with a single hyphen

    return $input;
}

sub seperate_front_matter {
    my ($md) = @_;
    my $re = "^---\n([^(---)]+)\n---\n";
    
    $md =~ $re or die "File does not contain front matter";
    my ($hr) = Load($1);
    $md =~ s/$re//g;
    return ($hr, $md);
}

sub parse_posts {
    my ($dir) = @_;
    my @issues;

    foreach my $f (glob "$dir/*.md") {
        print "$f\n";

        local $/;
        open(file, $f) or die "Can't read '$f'\n";
        my $content = <file>;
        close file;

        my ($hr, $body) = seperate_front_matter $content;

        my $issue = {};
        
        $issue->{'front_matter'} = $hr;
        $issue->{'body'} = markdown $body;

        push @issues, $issue;
    }

    return @issues;
}

sub render_post {
    my ($hr, $body) = @_;
    my %fm = %$hr;
    my $slug = slugify $fm{'title'} or die "Title is not set for post";
    my $type = $fm{'type'} or die "Type not set for post";
    my $mod = '';
    if ($type eq 'mod') {
        print $type, "is mod\n";
        $mod = $fm{'mod'} or die "Mod not set for post";
    }
        
    my $author = $fm{'author'}, or die "Author not set for post";
    my %vars = (
        slug => $slug,
        body => mark_raw($body),
        title => $fm{'title'},
        type => $type,
        author => $author,
        mod => $mod,
        );
    #print Dumper([\%vars]);
    my $r = $tl->render($post_template, \%vars);

    return (\%vars, $r);
}

my @issues = parse_posts $post_dir;
my @rendered;
my @bodies;

foreach my $issue (@issues) {
    my ($meta, $body) = render_post($issue->{'front_matter'}, $issue->{'body'});
    push @rendered, $meta;
    push @bodies, $body;
}


my @mods;
my @other;
foreach my $r (@rendered) {
    if ($r->{'type'} == 'mod') {
        push @mods, $r;
    } else {
        push @other, $r;
    }
}


my %vars = ( mods => \@mods, other => \@other, content => \@bodies, title => $title );
my $post = $tl->render($issue_template, \%vars);

print $post;
