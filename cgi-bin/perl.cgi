#!/usr/bin/env perl
use strict;
use warnings;
use CGI;
use Image::Magick;

my $q = CGI->new;

print $q->header(-type => "image/png");

my $shape = $q->param("shape") || "square";
my $upload = $q->upload("image");

my $img = Image::Magick->new;
$img->Read($upload);

# 枠の色（チームみらい）
my $color = "#89C997";

# 枠の太さ
my $border = 20;

# 元画像サイズ
my ($w, $h) = $img->Get('width', 'height');

# 枠の分だけ縮小
my $scale_w = $w - $border * 2;
my $scale_h = $h - $border * 2;

my $scaled = $img->Clone();
$scaled->Resize(width => $scale_w, height => $scale_h);

# 新しいキャンバス（枠込み）
my $canvas = Image::Magick->new;
$canvas->Set(size => "${w}x${h}");
$canvas->ReadImage("xc:white");

# 枠を描画
if ($shape eq "circle") {
    $canvas->Draw(
        primitive => 'circle',
        stroke    => $color,
        strokewidth => $border,
        fill      => 'none',
        points    => sprintf("%d,%d %d,%d", $w/2, $h/2, $w/2, $border)
    );
} else {
    $canvas->Draw(
        primitive => 'rectangle',
        stroke    => $color,
        strokewidth => $border,
        fill      => 'none',
        points    => "0,0 $w,$h"
    );
}

# 中央に縮小画像を合成
$canvas->Composite(
    image => $scaled,
    compose => 'Over',
    x => $border,
    y => $border
);

# PNG 出力
binmode STDOUT;
print $canvas->ImageToBlob(magick => 'png');
