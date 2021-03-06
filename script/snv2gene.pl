#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Basename;
use Data::Printer;
use Data::Dumper;
use feature qw/ say /;

use FindBin '$Script';

use Getopt::Long qw/ GetOptions /;

my $snv_in;
my $help;
my $features = '/Users/Nick_curie/Documents/Curie/Data/Genomes/Dmel_v6.12/Features/dmel-all-r6.12.gtf';
my $type = 'snv';

GetOptions( 'infile=s'         =>    \$snv_in,
            'features=s'       =>    \$features,
            'type=s'           =>    \$type,
            'help'             =>    \$help
    ) or die usage();

if ($help) { exit usage() }

if (not $snv_in and not $features ){
  exit usage();
}

my (%transcript_length, %genes, %features);

my ($sample, $annotated_snvs, $genes_out, $bp_out);


mkdir 'data' unless -d 'data';

make_gene_hash($features);
annotate_SNVs($snv_in, $type);

sub make_gene_hash {
  my $bed_file = shift;

  open my $bed_in, '<', $bed_file;
  my %exons;

  while(<$bed_in>){
    chomp;
    my ($chrom, $feature, $start, $stop, $id, $gene) = (split)[0,2,3,4,9,11];
    ($gene) = $gene =~ /\"(.*)\";/;
    ($id) = $id =~ /\"(.*)\";/;

    if ($feature eq 'gene'){
      $genes{$chrom}{$gene} = [$start, $stop, $id];
    }

    else {
      my $transcript = (split)[13];
      ($transcript) = $transcript =~ /\"(.*)\";/;
      my $feature_length = ($stop - $start);
      if ($feature eq 'exon'){
        $exons{$transcript}{$feature}++;
        $feature = $feature . "_" . $exons{$transcript}{$feature};
      }
      $transcript_length{$chrom}{$gene}{$transcript} += $feature_length;
      $features{$chrom}{$gene}{$transcript}{$feature} = [$start, $stop, $feature_length];
    }
  }

}

sub annotate_SNVs {
  my ($in, $type) = @_;

  open my $snv_in, '<', $in;

  if ($type eq 'indel'){
    open $annotated_snvs, '>', "data/annotated_indels.txt";
  }
  else {
    open $annotated_snvs, '>', "data/annotated_snvs.txt";
  }

  if ( -z $annotated_snvs ) {
    say "Adding header to file";
    print $annotated_snvs join("\t", "sample", "chromosome", "pos", "ref", "alt", "trinuc", "trans", "decomp_trinuc", "grouped_trans", "allele_frequency", "caller", "variant_type", "status", "snpEff_anno", "feature", "gene", "id") . "\n";
  }

  my $call = 1;

  # This allows files to be parsed irrespective of line ending. Not recommened for large files
  while(<$snv_in>){
    chomp;
    my ($sample, $chrom, $pos) = (split)[0..2];

    my (%hits, $hit_ref);
    # my @hit_genes;
    my ($hit_gene, $hit_feature, $hit_id);
    my $hit_object = "intergenic";

    ($hit_object, $hit_feature, $hit_gene, $hit_id,  $hit_ref) = getbps($chrom, $pos, $hit_object, \%hits);
    %hits = %{ $hit_ref };

    say "$type in sample $sample: $chrom\:$pos is in $hit_object";

    print $annotated_snvs join("\t", $_, $hit_feature, $hit_gene, $hit_id) . "\n";
    # $call++;
  }
}

sub getbps {
  my ($chrom, $pos, $hit_feature, $hit_ref) = @_;

  my %hits = %{$hit_ref};
  my %smallest_hit_feature;
  my $bp_feature = "intergenic";
  my $bp_gene = "intergenic";
  my $bp_gene_id = "intergenic";


  for my $gene ( sort { $genes{$chrom}{$a}[0] <=> $genes{$chrom}{$b}[0] } keys %{$genes{$chrom}} ){
    # Smallest features are last (and will then replace larger overlapping features i.e. exon over CDS)
    my %smallest_hit_feature;

    my $gene_id = $genes{$chrom}{$gene}[2];

    for my $transcript ( sort keys %{$transcript_length{$chrom}{$gene}}){

    for my $feature ( sort { $features{$chrom}{$gene}{$transcript}{$b}[2] <=> $features{$chrom}{$gene}{$transcript}{$a}[2] } keys %{$features{$chrom}{$gene}{$transcript}}){

      # print join(",", $gene, $transcript, $transcript_length{$chrom}{$gene}{$transcript}, $feature, $features{$chrom}{$gene}{$transcript}{$feature}[2]  ) . "\n";

      my ($feature_start, $feature_stop, $length) = @{$features{$chrom}{$gene}{$transcript}{$feature}};

      $feature = "intron" if $feature eq 'gene';
      $feature = "intron" if $feature eq 'mRNA';

      # if breakpoint contained in feature
      if ( $pos >= $feature_start and $pos <= $feature_stop ) {
        # save gene containing BP
        # push @hit_genes, $gene unless $hits{$gene};
        $hits{$gene}++;

        # take smallest feature that is hit accross all transcript
        if ( (not exists $smallest_hit_feature{$gene}) or ( $smallest_hit_feature{$gene} > $length ) ){
          $smallest_hit_feature{$gene} = $length;
          $bp_feature = $feature;
          $bp_feature = 'exon' if $bp_feature eq 'CDS';
          $bp_gene = $gene;
          $bp_gene_id = $gene_id;
          $hit_feature = "$gene, $bp_feature";

        }

      }
    }
  }

}
  return ($hit_feature, $bp_feature, $bp_gene, $bp_gene_id, \%hits);
}

sub usage {
  print
"
usage: $Script [-h] [opts]

sv2gene
author: Nick Riddiford (nick.riddiford\@curie.fr)
version: v1.0
description: Annotate SNVs for genomic features and genes

arguments:
  -h, --help            show this help message and exit
  -i --infile
                        SV calls file (as produced by svParser)[required]
  -f FEATURES --features
                        Features file to annotate from (should be in .gtf format)
"
}
