// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.9

part of hermit.ui;

// Some methods in this file assert that their arguments are not null. These
// asserts are just to improve the error messages; they should only cover
// arguments that are either dereferenced _in Dart_, before being passed to the
// engine, or that the engine explicitly null-checks itself (after attempting to
// convert the argument to a native type). It should not be possible for a null
// or invalid value to be used by the engine even in release mode, since that
// would cause a crash. It is, however, acceptable for error messages to be much
// less useful or correct in release mode than in debug mode.
//
// Painting APIs will also warn about arguments representing NaN coordinates,
// which can not be rendered by Skia.

// Update this list when changing the list of supported codecs.
/// {@template flutter.dart:ui.imageFormats}
/// JPEG, PNG, GIF, Animated GIF, WebP, Animated WebP, BMP, and WBMP
/// {@endtemplate}

bool _rectIsValid(Rect rect) {
  assert(rect != null, 'Rect argument was null.'); // ignore: unnecessary_null_comparison
  assert(!rect.hasNaN, 'Rect argument contained a NaN value.');
  return true;
}

bool _rrectIsValid(RRect rrect) {
  assert(rrect != null, 'RRect argument was null.'); // ignore: unnecessary_null_comparison
  assert(!rrect.hasNaN, 'RRect argument contained a NaN value.');
  return true;
}

bool _offsetIsValid(Offset offset) {
  assert(offset != null, 'Offset argument was null.'); // ignore: unnecessary_null_comparison
  assert(!offset.dx.isNaN && !offset.dy.isNaN, 'Offset argument contained a NaN value.');
  return true;
}

bool _matrix4IsValid(Float64List matrix4) {
  assert(matrix4 != null, 'Matrix4 argument was null.'); // ignore: unnecessary_null_comparison
  assert(matrix4.length == 16, 'Matrix4 must have 16 entries.');
  assert(matrix4.every((double value) => value.isFinite), 'Matrix4 entries must be finite.');
  return true;
}

bool _radiusIsValid(Radius radius) {
  assert(radius != null, 'Radius argument was null.'); // ignore: unnecessary_null_comparison
  assert(!radius.x.isNaN && !radius.y.isNaN, 'Radius argument contained a NaN value.');
  return true;
}

Color _scaleAlpha(Color a, double factor) {
  return a.withAlpha((a.alpha * factor).round().clamp(0, 255) as int);
}

/// An immutable 32 bit color value in ARGB format.
///
/// Consider the light teal of the Flutter logo. It is fully opaque, with a red
/// channel value of 0x42 (66), a green channel value of 0xA5 (165), and a blue
/// channel value of 0xF5 (245). In the common "hash syntax" for color values,
/// it would be described as `#42A5F5`.
///
/// Here are some ways it could be constructed:
///
/// ```dart
/// Color c = const Color(0xFF42A5F5);
/// Color c = const Color.fromARGB(0xFF, 0x42, 0xA5, 0xF5);
/// Color c = const Color.fromARGB(255, 66, 165, 245);
/// Color c = const Color.fromRGBO(66, 165, 245, 1.0);
/// ```
///
/// If you are having a problem with `Color` wherein it seems your color is just
/// not painting, check to make sure you are specifying the full 8 hexadecimal
/// digits. If you only specify six, then the leading two digits are assumed to
/// be zero, which means fully-transparent:
///
/// ```dart
/// Color c1 = const Color(0xFFFFFF); // fully transparent white (invisible)
/// Color c2 = const Color(0xFFFFFFFF); // fully opaque white (visible)
/// ```
///
/// See also:
///
///  * [Colors](https://docs.flutter.io/flutter/material/Colors-class.html), which
///    defines the colors found in the Material Design specification.
class Color {
  /// Construct a color from the lower 32 bits of an [int].
  ///
  /// The bits are interpreted as follows:
  ///
  /// * Bits 24-31 are the alpha value.
  /// * Bits 16-23 are the red value.
  /// * Bits 8-15 are the green value.
  /// * Bits 0-7 are the blue value.
  ///
  /// In other words, if AA is the alpha value in hex, RR the red value in hex,
  /// GG the green value in hex, and BB the blue value in hex, a color can be
  /// expressed as `const Color(0xAARRGGBB)`.
  ///
  /// For example, to get a fully opaque orange, you would use `const
  /// Color(0xFFFF9000)` (`FF` for the alpha, `FF` for the red, `90` for the
  /// green, and `00` for the blue).
  @pragma('vm:entry-point')
  const Color(int value) : value = value & 0xFFFFFFFF;

  /// Construct a color from the lower 8 bits of four integers.
  ///
  /// * `a` is the alpha value, with 0 being transparent and 255 being fully
  ///   opaque.
  /// * `r` is [red], from 0 to 255.
  /// * `g` is [green], from 0 to 255.
  /// * `b` is [blue], from 0 to 255.
  ///
  /// Out of range values are brought into range using modulo 255.
  ///
  /// See also [fromRGBO], which takes the alpha value as a floating point
  /// value.
  const Color.fromARGB(int a, int r, int g, int b) :
    value = (((a & 0xff) << 24) |
             ((r & 0xff) << 16) |
             ((g & 0xff) << 8)  |
             ((b & 0xff) << 0)) & 0xFFFFFFFF;

  /// Create a color from red, green, blue, and opacity, similar to `rgba()` in CSS.
  ///
  /// * `r` is [red], from 0 to 255.
  /// * `g` is [green], from 0 to 255.
  /// * `b` is [blue], from 0 to 255.
  /// * `opacity` is alpha channel of this color as a double, with 0.0 being
  ///   transparent and 1.0 being fully opaque.
  ///
  /// Out of range values are brought into range using modulo 255.
  ///
  /// See also [fromARGB], which takes the opacity as an integer value.
  const Color.fromRGBO(int r, int g, int b, double opacity) :
    value = ((((opacity * 0xff ~/ 1) & 0xff) << 24) |
              ((r                    & 0xff) << 16) |
              ((g                    & 0xff) << 8)  |
              ((b                    & 0xff) << 0)) & 0xFFFFFFFF;

  /// A 32 bit value representing this color.
  ///
  /// The bits are assigned as follows:
  ///
  /// * Bits 24-31 are the alpha value.
  /// * Bits 16-23 are the red value.
  /// * Bits 8-15 are the green value.
  /// * Bits 0-7 are the blue value.
  final int value;

  /// The alpha channel of this color in an 8 bit value.
  ///
  /// A value of 0 means this color is fully transparent. A value of 255 means
  /// this color is fully opaque.
  int get alpha => (0xff000000 & value) >> 24;

  /// The alpha channel of this color as a double.
  ///
  /// A value of 0.0 means this color is fully transparent. A value of 1.0 means
  /// this color is fully opaque.
  double get opacity => alpha / 0xFF;

  /// The red channel of this color in an 8 bit value.
  int get red => (0x00ff0000 & value) >> 16;

  /// The green channel of this color in an 8 bit value.
  int get green => (0x0000ff00 & value) >> 8;

  /// The blue channel of this color in an 8 bit value.
  int get blue => (0x000000ff & value) >> 0;

  /// Returns a new color that matches this color with the alpha channel
  /// replaced with `a` (which ranges from 0 to 255).
  ///
  /// Out of range values will have unexpected effects.
  Color withAlpha(int a) {
    return Color.fromARGB(a, red, green, blue);
  }

  /// Returns a new color that matches this color with the alpha channel
  /// replaced with the given `opacity` (which ranges from 0.0 to 1.0).
  ///
  /// Out of range values will have unexpected effects.
  Color withOpacity(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0);
    return withAlpha((255.0 * opacity).round());
  }

  /// Returns a new color that matches this color with the red channel replaced
  /// with `r` (which ranges from 0 to 255).
  ///
  /// Out of range values will have unexpected effects.
  Color withRed(int r) {
    return Color.fromARGB(alpha, r, green, blue);
  }

  /// Returns a new color that matches this color with the green channel
  /// replaced with `g` (which ranges from 0 to 255).
  ///
  /// Out of range values will have unexpected effects.
  Color withGreen(int g) {
    return Color.fromARGB(alpha, red, g, blue);
  }

  /// Returns a new color that matches this color with the blue channel replaced
  /// with `b` (which ranges from 0 to 255).
  ///
  /// Out of range values will have unexpected effects.
  Color withBlue(int b) {
    return Color.fromARGB(alpha, red, green, b);
  }

  // See <https://www.w3.org/TR/WCAG20/#relativeluminancedef>
  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928)
      return component / 12.92;
    return math.pow((component + 0.055) / 1.055, 2.4) as double;
  }

  /// Returns a brightness value between 0 for darkest and 1 for lightest.
  ///
  /// Represents the relative luminance of the color. This value is computationally
  /// expensive to calculate.
  ///
  /// See <https://en.wikipedia.org/wiki/Relative_luminance>.
  double computeLuminance() {
    // See <https://www.w3.org/TR/WCAG20/#relativeluminancedef>
    final double R = _linearizeColorComponent(red / 0xFF);
    final double G = _linearizeColorComponent(green / 0xFF);
    final double B = _linearizeColorComponent(blue / 0xFF);
    return 0.2126 * R + 0.7152 * G + 0.0722 * B;
  }

  /// Linearly interpolate between two colors.
  ///
  /// This is intended to be fast but as a result may be ugly. Consider
  /// [HSVColor] or writing custom logic for interpolating colors.
  ///
  /// If either color is null, this function linearly interpolates from a
  /// transparent instance of the other color. This is usually preferable to
  /// interpolating from [material.Colors.transparent] (`const
  /// Color(0x00000000)`), which is specifically transparent _black_.
  ///
  /// The `t` argument represents position on the timeline, with 0.0 meaning
  /// that the interpolation has not started, returning `a` (or something
  /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
  /// returning `b` (or something equivalent to `b`), and values in between
  /// meaning that the interpolation is at the relevant point on the timeline
  /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
  /// 1.0, so negative values and values greater than 1.0 are valid (and can
  /// easily be generated by curves such as [Curves.elasticInOut]). Each channel
  /// will be clamped to the range 0 to 255.
  ///
  /// Values for `t` are usually obtained from an [Animation<double>], such as
  /// an [AnimationController].
  static Color? lerp(Color? a, Color? b, double t) {
    assert(t != null); // ignore: unnecessary_null_comparison
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return _scaleAlpha(a, 1.0 - t);
      }
    } else {
      if (a == null) {
        return _scaleAlpha(b, t);
      } else {
        return Color.fromARGB(
          _clampInt(_lerpInt(a.alpha, b.alpha, t).toInt(), 0, 255),
          _clampInt(_lerpInt(a.red, b.red, t).toInt(), 0, 255),
          _clampInt(_lerpInt(a.green, b.green, t).toInt(), 0, 255),
          _clampInt(_lerpInt(a.blue, b.blue, t).toInt(), 0, 255),
        );
      }
    }
  }

  /// Combine the foreground color as a transparent color over top
  /// of a background color, and return the resulting combined color.
  ///
  /// This uses standard alpha blending ("SRC over DST") rules to produce a
  /// blended color from two colors. This can be used as a performance
  /// enhancement when trying to avoid needless alpha blending compositing
  /// operations for two things that are solid colors with the same shape, but
  /// overlay each other: instead, just paint one with the combined color.
  static Color alphaBlend(Color foreground, Color background) {
    final int alpha = foreground.alpha;
    if (alpha == 0x00) { // Foreground completely transparent.
      return background;
    }
    final int invAlpha = 0xff - alpha;
    int backAlpha = background.alpha;
    if (backAlpha == 0xff) { // Opaque background case
      return Color.fromARGB(
        0xff,
        (alpha * foreground.red + invAlpha * background.red) ~/ 0xff,
        (alpha * foreground.green + invAlpha * background.green) ~/ 0xff,
        (alpha * foreground.blue + invAlpha * background.blue) ~/ 0xff,
      );
    } else { // General case
      backAlpha = (backAlpha * invAlpha) ~/ 0xff;
      final int outAlpha = alpha + backAlpha;
      assert(outAlpha != 0x00);
      return Color.fromARGB(
        outAlpha,
        (foreground.red * alpha + background.red * backAlpha) ~/ outAlpha,
        (foreground.green * alpha + background.green * backAlpha) ~/ outAlpha,
        (foreground.blue * alpha + background.blue * backAlpha) ~/ outAlpha,
      );
    }
  }

  /// Returns an alpha value representative of the provided [opacity] value.
  ///
  /// The [opacity] value may not be null.
  static int getAlphaFromOpacity(double opacity) {
    assert(opacity != null); // ignore: unnecessary_null_comparison
    return (opacity.clamp(0.0, 1.0) * 255).round();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is Color
        && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Color(0x${value.toRadixString(16).padLeft(8, '0')})';
}

/// Algorithms to use when painting on the canvas.
///
/// When drawing a shape or image onto a canvas, different algorithms can be
/// used to blend the pixels. The different values of [BlendMode] specify
/// different such algorithms.
///
/// Each algorithm has two inputs, the _source_, which is the image being drawn,
/// and the _destination_, which is the image into which the source image is
/// being composited. The destination is often thought of as the _background_.
/// The source and destination both have four color channels, the red, green,
/// blue, and alpha channels. These are typically represented as numbers in the
/// range 0.0 to 1.0. The output of the algorithm also has these same four
/// channels, with values computed from the source and destination.
///
/// The documentation of each value below describes how the algorithm works. In
/// each case, an image shows the output of blending a source image with a
/// destination image. In the images below, the destination is represented by an
/// image with horizontal lines and an opaque landscape photograph, and the
/// source is represented by an image with vertical lines (the same lines but
/// rotated) and a bird clip-art image. The [src] mode shows only the source
/// image, and the [dst] mode shows only the destination image. In the
/// documentation below, the transparency is illustrated by a checkerboard
/// pattern. The [clear] mode drops both the source and destination, resulting
/// in an output that is entirely transparent (illustrated by a solid
/// checkerboard pattern).
///
/// The horizontal and vertical bars in these images show the red, green, and
/// blue channels with varying opacity levels, then all three color channels
/// together with those same varying opacity levels, then all three color
/// channels set to zero with those varying opacity levels, then two bars showing
/// a red/green/blue repeating gradient, the first with full opacity and the
/// second with partial opacity, and finally a bar with the three color channels
/// set to zero but the opacity varying in a repeating gradient.
///
/// ## Application to the [Canvas] API
///
/// When using [Canvas.saveLayer] and [Canvas.restore], the blend mode of the
/// [Paint] given to the [Canvas.saveLayer] will be applied when
/// [Canvas.restore] is called. Each call to [Canvas.saveLayer] introduces a new
/// layer onto which shapes and images are painted; when [Canvas.restore] is
/// called, that layer is then composited onto the parent layer, with the source
/// being the most-recently-drawn shapes and images, and the destination being
/// the parent layer. (For the first [Canvas.saveLayer] call, the parent layer
/// is the canvas itself.)
///
/// See also:
///
///  * [Paint.blendMode], which uses [BlendMode] to define the compositing
///    strategy.
enum BlendMode {
  // This list comes from Skia's SkXfermode.h and the values (order) should be
  // kept in sync.
  // See: https://skia.org/user/api/skpaint#SkXfermode

  /// Drop both the source and destination images, leaving nothing.
  ///
  /// This corresponds to the "clear" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_clear.png)
  clear,

  /// Drop the destination image, only paint the source image.
  ///
  /// Conceptually, the destination is first cleared, then the source image is
  /// painted.
  ///
  /// This corresponds to the "Copy" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_src.png)
  src,

  /// Drop the source image, only paint the destination image.
  ///
  /// Conceptually, the source image is discarded, leaving the destination
  /// untouched.
  ///
  /// This corresponds to the "Destination" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_dst.png)
  dst,

  /// Composite the source image over the destination image.
  ///
  /// This is the default value. It represents the most intuitive case, where
  /// shapes are painted on top of what is below, with transparent areas showing
  /// the destination layer.
  ///
  /// This corresponds to the "Source over Destination" Porter-Duff operator,
  /// also known as the Painter's Algorithm.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_srcOver.png)
  srcOver,

  /// Composite the source image under the destination image.
  ///
  /// This is the opposite of [srcOver].
  ///
  /// This corresponds to the "Destination over Source" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_dstOver.png)
  ///
  /// This is useful when the source image should have been painted before the
  /// destination image, but could not be.
  dstOver,

  /// Show the source image, but only where the two images overlap. The
  /// destination image is not rendered, it is treated merely as a mask. The
  /// color channels of the destination are ignored, only the opacity has an
  /// effect.
  ///
  /// To show the destination image instead, consider [dstIn].
  ///
  /// To reverse the semantic of the mask (only showing the source where the
  /// destination is absent, rather than where it is present), consider
  /// [srcOut].
  ///
  /// This corresponds to the "Source in Destination" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_srcIn.png)
  srcIn,

  /// Show the destination image, but only where the two images overlap. The
  /// source image is not rendered, it is treated merely as a mask. The color
  /// channels of the source are ignored, only the opacity has an effect.
  ///
  /// To show the source image instead, consider [srcIn].
  ///
  /// To reverse the semantic of the mask (only showing the source where the
  /// destination is present, rather than where it is absent), consider [dstOut].
  ///
  /// This corresponds to the "Destination in Source" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_dstIn.png)
  dstIn,

  /// Show the source image, but only where the two images do not overlap. The
  /// destination image is not rendered, it is treated merely as a mask. The color
  /// channels of the destination are ignored, only the opacity has an effect.
  ///
  /// To show the destination image instead, consider [dstOut].
  ///
  /// To reverse the semantic of the mask (only showing the source where the
  /// destination is present, rather than where it is absent), consider [srcIn].
  ///
  /// This corresponds to the "Source out Destination" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_srcOut.png)
  srcOut,

  /// Show the destination image, but only where the two images do not overlap. The
  /// source image is not rendered, it is treated merely as a mask. The color
  /// channels of the source are ignored, only the opacity has an effect.
  ///
  /// To show the source image instead, consider [srcOut].
  ///
  /// To reverse the semantic of the mask (only showing the destination where the
  /// source is present, rather than where it is absent), consider [dstIn].
  ///
  /// This corresponds to the "Destination out Source" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_dstOut.png)
  dstOut,

  /// Composite the source image over the destination image, but only where it
  /// overlaps the destination.
  ///
  /// This corresponds to the "Source atop Destination" Porter-Duff operator.
  ///
  /// This is essentially the [srcOver] operator, but with the output's opacity
  /// channel being set to that of the destination image instead of being a
  /// combination of both image's opacity channels.
  ///
  /// For a variant with the destination on top instead of the source, see
  /// [dstATop].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_srcATop.png)
  srcATop,

  /// Composite the destination image over the source image, but only where it
  /// overlaps the source.
  ///
  /// This corresponds to the "Destination atop Source" Porter-Duff operator.
  ///
  /// This is essentially the [dstOver] operator, but with the output's opacity
  /// channel being set to that of the source image instead of being a
  /// combination of both image's opacity channels.
  ///
  /// For a variant with the source on top instead of the destination, see
  /// [srcATop].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_dstATop.png)
  dstATop,

  /// Apply a bitwise `xor` operator to the source and destination images. This
  /// leaves transparency where they would overlap.
  ///
  /// This corresponds to the "Source xor Destination" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_xor.png)
  xor,

  /// Sum the components of the source and destination images.
  ///
  /// Transparency in a pixel of one of the images reduces the contribution of
  /// that image to the corresponding output pixel, as if the color of that
  /// pixel in that image was darker.
  ///
  /// This corresponds to the "Source plus Destination" Porter-Duff operator.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_plus.png)
  plus,

  /// Multiply the color components of the source and destination images.
  ///
  /// This can only result in the same or darker colors (multiplying by white,
  /// 1.0, results in no change; multiplying by black, 0.0, results in black).
  ///
  /// When compositing two opaque images, this has similar effect to overlapping
  /// two transparencies on a projector.
  ///
  /// For a variant that also multiplies the alpha channel, consider [multiply].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_modulate.png)
  ///
  /// See also:
  ///
  ///  * [screen], which does a similar computation but inverted.
  ///  * [overlay], which combines [modulate] and [screen] to favor the
  ///    destination image.
  ///  * [hardLight], which combines [modulate] and [screen] to favor the
  ///    source image.
  modulate,

  // Following blend modes are defined in the CSS Compositing standard.

  /// Multiply the inverse of the components of the source and destination
  /// images, and inverse the result.
  ///
  /// Inverting the components means that a fully saturated channel (opaque
  /// white) is treated as the value 0.0, and values normally treated as 0.0
  /// (black, transparent) are treated as 1.0.
  ///
  /// This is essentially the same as [modulate] blend mode, but with the values
  /// of the colors inverted before the multiplication and the result being
  /// inverted back before rendering.
  ///
  /// This can only result in the same or lighter colors (multiplying by black,
  /// 1.0, results in no change; multiplying by white, 0.0, results in white).
  /// Similarly, in the alpha channel, it can only result in more opaque colors.
  ///
  /// This has similar effect to two projectors displaying their images on the
  /// same screen simultaneously.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_screen.png)
  ///
  /// See also:
  ///
  ///  * [modulate], which does a similar computation but without inverting the
  ///    values.
  ///  * [overlay], which combines [modulate] and [screen] to favor the
  ///    destination image.
  ///  * [hardLight], which combines [modulate] and [screen] to favor the
  ///    source image.
  screen,  // The last coeff mode.

  /// Multiply the components of the source and destination images after
  /// adjusting them to favor the destination.
  ///
  /// Specifically, if the destination value is smaller, this multiplies it with
  /// the source value, whereas is the source value is smaller, it multiplies
  /// the inverse of the source value with the inverse of the destination value,
  /// then inverts the result.
  ///
  /// Inverting the components means that a fully saturated channel (opaque
  /// white) is treated as the value 0.0, and values normally treated as 0.0
  /// (black, transparent) are treated as 1.0.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_overlay.png)
  ///
  /// See also:
  ///
  ///  * [modulate], which always multiplies the values.
  ///  * [screen], which always multiplies the inverses of the values.
  ///  * [hardLight], which is similar to [overlay] but favors the source image
  ///    instead of the destination image.
  overlay,

  /// Composite the source and destination image by choosing the lowest value
  /// from each color channel.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_darken.png)
  darken,

  /// Composite the source and destination image by choosing the highest value
  /// from each color channel.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_lighten.png)
  lighten,

  /// Divide the destination by the inverse of the source.
  ///
  /// Inverting the components means that a fully saturated channel (opaque
  /// white) is treated as the value 0.0, and values normally treated as 0.0
  /// (black, transparent) are treated as 1.0.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_colorDodge.png)
  colorDodge,

  /// Divide the inverse of the destination by the source, and inverse the result.
  ///
  /// Inverting the components means that a fully saturated channel (opaque
  /// white) is treated as the value 0.0, and values normally treated as 0.0
  /// (black, transparent) are treated as 1.0.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_colorBurn.png)
  colorBurn,

  /// Multiply the components of the source and destination images after
  /// adjusting them to favor the source.
  ///
  /// Specifically, if the source value is smaller, this multiplies it with the
  /// destination value, whereas is the destination value is smaller, it
  /// multiplies the inverse of the destination value with the inverse of the
  /// source value, then inverts the result.
  ///
  /// Inverting the components means that a fully saturated channel (opaque
  /// white) is treated as the value 0.0, and values normally treated as 0.0
  /// (black, transparent) are treated as 1.0.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_hardLight.png)
  ///
  /// See also:
  ///
  ///  * [modulate], which always multiplies the values.
  ///  * [screen], which always multiplies the inverses of the values.
  ///  * [overlay], which is similar to [hardLight] but favors the destination
  ///    image instead of the source image.
  hardLight,

  /// Use [colorDodge] for source values below 0.5 and [colorBurn] for source
  /// values above 0.5.
  ///
  /// This results in a similar but softer effect than [overlay].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_softLight.png)
  ///
  /// See also:
  ///
  ///  * [color], which is a more subtle tinting effect.
  softLight,

  /// Subtract the smaller value from the bigger value for each channel.
  ///
  /// Compositing black has no effect; compositing white inverts the colors of
  /// the other image.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver].
  ///
  /// The effect is similar to [exclusion] but harsher.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_difference.png)
  difference,

  /// Subtract double the product of the two images from the sum of the two
  /// images.
  ///
  /// Compositing black has no effect; compositing white inverts the colors of
  /// the other image.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver].
  ///
  /// The effect is similar to [difference] but softer.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_exclusion.png)
  exclusion,

  /// Multiply the components of the source and destination images, including
  /// the alpha channel.
  ///
  /// This can only result in the same or darker colors (multiplying by white,
  /// 1.0, results in no change; multiplying by black, 0.0, results in black).
  ///
  /// Since the alpha channel is also multiplied, a fully-transparent pixel
  /// (opacity 0.0) in one image results in a fully transparent pixel in the
  /// output. This is similar to [dstIn], but with the colors combined.
  ///
  /// For a variant that multiplies the colors but does not multiply the alpha
  /// channel, consider [modulate].
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_multiply.png)
  multiply,  // The last separable mode.

  /// Take the hue of the source image, and the saturation and luminosity of the
  /// destination image.
  ///
  /// The effect is to tint the destination image with the source image.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver]. Regions that are entirely transparent in the source image take
  /// their hue from the destination.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_hue.png)
  ///
  /// See also:
  ///
  ///  * [color], which is a similar but stronger effect as it also applies the
  ///    saturation of the source image.
  ///  * [HSVColor], which allows colors to be expressed using Hue rather than
  ///    the red/green/blue channels of [Color].
  hue,

  /// Take the saturation of the source image, and the hue and luminosity of the
  /// destination image.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver]. Regions that are entirely transparent in the source image take
  /// their saturation from the destination.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_hue.png)
  ///
  /// See also:
  ///
  ///  * [color], which also applies the hue of the source image.
  ///  * [luminosity], which applies the luminosity of the source image to the
  ///    destination.
  saturation,

  /// Take the hue and saturation of the source image, and the luminosity of the
  /// destination image.
  ///
  /// The effect is to tint the destination image with the source image.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver]. Regions that are entirely transparent in the source image take
  /// their hue and saturation from the destination.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_color.png)
  ///
  /// See also:
  ///
  ///  * [hue], which is a similar but weaker effect.
  ///  * [softLight], which is a similar tinting effect but also tints white.
  ///  * [saturation], which only applies the saturation of the source image.
  color,

  /// Take the luminosity of the source image, and the hue and saturation of the
  /// destination image.
  ///
  /// The opacity of the output image is computed in the same way as for
  /// [srcOver]. Regions that are entirely transparent in the source image take
  /// their luminosity from the destination.
  ///
  /// ![](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/blend_mode_luminosity.png)
  ///
  /// See also:
  ///
  ///  * [saturation], which applies the saturation of the source image to the
  ///    destination.
  ///  * [ImageFilter.blur], which can be used with [BackdropFilter] for a
  ///    related effect.
  luminosity,
}

/// Quality levels for image filters.
///
/// See [Paint.filterQuality].
enum FilterQuality {
  // This list comes from Skia's SkFilterQuality.h and the values (order) should
  // be kept in sync.

  /// Fastest possible filtering, albeit also the lowest quality.
  ///
  /// Typically this implies nearest-neighbor filtering.
  none,

  /// Better quality than [none], faster than [medium].
  ///
  /// Typically this implies bilinear interpolation.
  low,

  /// Better quality than [low], faster than [high].
  ///
  /// Typically this implies a combination of bilinear interpolation and
  /// pyramidal parametric pre-filtering (mipmaps).
  medium,

  /// Best possible quality filtering, albeit also the slowest.
  ///
  /// Typically this implies bicubic interpolation or better.
  high,
}

/// Styles to use for line endings.
///
/// See also:
///
///  * [Paint.strokeCap] for how this value is used.
///  * [StrokeJoin] for the different kinds of line segment joins.
// These enum values must be kept in sync with SkPaint::Cap.
enum StrokeCap {
  /// Begin and end contours with a flat edge and no extension.
  ///
  /// ![A butt cap ends line segments with a square end that stops at the end of
  /// the line segment.](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/butt_cap.png)
  ///
  /// Compare to the [square] cap, which has the same shape, but extends past
  /// the end of the line by half a stroke width.
  butt,

  /// Begin and end contours with a semi-circle extension.
  ///
  /// ![A round cap adds a rounded end to the line segment that protrudes
  /// by one half of the thickness of the line (which is the radius of the cap)
  /// past the end of the segment.](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/round_cap.png)
  ///
  /// The cap is colored in the diagram above to highlight it: in normal use it
  /// is the same color as the line.
  round,

  /// Begin and end contours with a half square extension. This is
  /// similar to extending each contour by half the stroke width (as
  /// given by [Paint.strokeWidth]).
  ///
  /// ![A square cap has a square end that effectively extends the line length
  /// by half of the stroke width.](https://flutter.github.io/assets-for-api-docs/assets/dart-ui/square_cap.png)
  ///
  /// The cap is colored in the diagram above to highlight it: in normal use it
  /// is the same color as the line.
  ///
  /// Compare to the [butt] cap, which has the same shape, but doesn't extend
  /// past the end of the line.
  square,
}

/// Styles to use for line segment joins.
///
/// This only affects line joins for polygons drawn by [Canvas.drawPath] and
/// rectangles, not points drawn as lines with [Canvas.drawPoints].
///
/// See also:
///
/// * [Paint.strokeJoin] and [Paint.strokeMiterLimit] for how this value is
///   used.
/// * [StrokeCap] for the different kinds of line endings.
// These enum values must be kept in sync with SkPaint::Join.
enum StrokeJoin {
  /// Joins between line segments form sharp corners.
  ///
  /// {@animation 300 300 https://flutter.github.io/assets-for-api-docs/assets/dart-ui/miter_4_join.mp4}
  ///
  /// The center of the line segment is colored in the diagram above to
  /// highlight the join, but in normal usage the join is the same color as the
  /// line.
  ///
  /// See also:
  ///
  ///   * [Paint.strokeJoin], used to set the line segment join style to this
  ///     value.
  ///   * [Paint.strokeMiterLimit], used to define when a miter is drawn instead
  ///     of a bevel when the join is set to this value.
  miter,

  /// Joins between line segments are semi-circular.
  ///
  /// {@animation 300 300 https://flutter.github.io/assets-for-api-docs/assets/dart-ui/round_join.mp4}
  ///
  /// The center of the line segment is colored in the diagram above to
  /// highlight the join, but in normal usage the join is the same color as the
  /// line.
  ///
  /// See also:
  ///
  ///   * [Paint.strokeJoin], used to set the line segment join style to this
  ///     value.
  round,

  /// Joins between line segments connect the corners of the butt ends of the
  /// line segments to give a beveled appearance.
  ///
  /// {@animation 300 300 https://flutter.github.io/assets-for-api-docs/assets/dart-ui/bevel_join.mp4}
  ///
  /// The center of the line segment is colored in the diagram above to
  /// highlight the join, but in normal usage the join is the same color as the
  /// line.
  ///
  /// See also:
  ///
  ///   * [Paint.strokeJoin], used to set the line segment join style to this
  ///     value.
  bevel,
}

/// Strategies for painting shapes and paths on a canvas.
///
/// See [Paint.style].
// These enum values must be kept in sync with SkPaint::Style.
enum PaintingStyle {
  // This list comes from Skia's SkPaint.h and the values (order) should be kept
  // in sync.

  /// Apply the [Paint] to the inside of the shape. For example, when
  /// applied to the [Canvas.drawCircle] call, this results in a disc
  /// of the given size being painted.
  fill,

  /// Apply the [Paint] to the edge of the shape. For example, when
  /// applied to the [Canvas.drawCircle] call, this results is a hoop
  /// of the given size being painted. The line drawn on the edge will
  /// be the width given by the [Paint.strokeWidth] property.
  stroke,
}


/// Different ways to clip a widget's content.
enum Clip {
  /// No clip at all.
  ///
  /// This is the default option for most widgets: if the content does not
  /// overflow the widget boundary, don't pay any performance cost for clipping.
  ///
  /// If the content does overflow, please explicitly specify the following
  /// [Clip] options:
  ///  * [hardEdge], which is the fastest clipping, but with lower fidelity.
  ///  * [antiAlias], which is a little slower than [hardEdge], but with smoothed edges.
  ///  * [antiAliasWithSaveLayer], which is much slower than [antiAlias], and should
  ///    rarely be used.
  none,

  /// Clip, but do not apply anti-aliasing.
  ///
  /// This mode enables clipping, but curves and non-axis-aligned straight lines will be
  /// jagged as no effort is made to anti-alias.
  ///
  /// Faster than other clipping modes, but slower than [none].
  ///
  /// This is a reasonable choice when clipping is needed, if the container is an axis-
  /// aligned rectangle or an axis-aligned rounded rectangle with very small corner radii.
  ///
  /// See also:
  ///
  ///  * [antiAlias], which is more reasonable when clipping is needed and the shape is not
  ///    an axis-aligned rectangle.
  hardEdge,

  /// Clip with anti-aliasing.
  ///
  /// This mode has anti-aliased clipping edges to achieve a smoother look.
  ///
  /// It' s much faster than [antiAliasWithSaveLayer], but slower than [hardEdge].
  ///
  /// This will be the common case when dealing with circles and arcs.
  ///
  /// Different from [hardEdge] and [antiAliasWithSaveLayer], this clipping may have
  /// bleeding edge artifacts.
  /// (See https://fiddle.skia.org/c/21cb4c2b2515996b537f36e7819288ae for an example.)
  ///
  /// See also:
  ///
  ///  * [hardEdge], which is a little faster, but with lower fidelity.
  ///  * [antiAliasWithSaveLayer], which is much slower, but can avoid the
  ///    bleeding edges if there's no other way.
  ///  * [Paint.isAntiAlias], which is the anti-aliasing switch for general draw operations.
  antiAlias,

  /// Clip with anti-aliasing and saveLayer immediately following the clip.
  ///
  /// This mode not only clips with anti-aliasing, but also allocates an offscreen
  /// buffer. All subsequent paints are carried out on that buffer before finally
  /// being clipped and composited back.
  ///
  /// This is very slow. It has no bleeding edge artifacts (that [antiAlias] has)
  /// but it changes the semantics as an offscreen buffer is now introduced.
  /// (See https://github.com/flutter/flutter/issues/18057#issuecomment-394197336
  /// for a difference between paint without saveLayer and paint with saveLayer.)
  ///
  /// This will be only rarely needed. One case where you might need this is if
  /// you have an image overlaid on a very different background color. In these
  /// cases, consider whether you can avoid overlaying multiple colors in one
  /// spot (e.g. by having the background color only present where the image is
  /// absent). If you can, [antiAlias] would be fine and much faster.
  ///
  /// See also:
  ///
  ///  * [antiAlias], which is much faster, and has similar clipping results.
  antiAliasWithSaveLayer,
}

/// Indicates that the image should not be resized in this dimension.
///
/// Used by [instantiateImageCodec] as a magical value to disable resizing
/// in the given dimension.
const int _kDoNotResizeDimension = -1;

Int32List _encodeColorList(List<Color> colors) {
  final int colorCount = colors.length;
  final Int32List result = Int32List(colorCount);
  for (int i = 0; i < colorCount; ++i)
    result[i] = colors[i].value;
  return result;
}

Float32List _encodePointList(List<Offset> points) {
  assert(points != null); // ignore: unnecessary_null_comparison
  final int pointCount = points.length;
  final Float32List result = Float32List(pointCount * 2);
  for (int i = 0; i < pointCount; ++i) {
    final int xIndex = i * 2;
    final int yIndex = xIndex + 1;
    final Offset point = points[i];
    assert(_offsetIsValid(point));
    result[xIndex] = point.dx;
    result[yIndex] = point.dy;
  }
  return result;
}

Float32List _encodeTwoPoints(Offset pointA, Offset pointB) {
  assert(_offsetIsValid(pointA));
  assert(_offsetIsValid(pointB));
  final Float32List result = Float32List(4);
  result[0] = pointA.dx;
  result[1] = pointA.dy;
  result[2] = pointB.dx;
  result[3] = pointB.dy;
  return result;
}

/// Generic callback signature, used by [_futurize].
typedef _Callback<T> = void Function(T result);

/// Signature for a method that receives a [_Callback].
///
/// Return value should be null on success, and a string error message on
/// failure.
typedef _Callbacker<T> = String? Function(_Callback<T> callback);

/// Converts a method that receives a value-returning callback to a method that
/// returns a Future.
///
/// Return a [String] to cause an [Exception] to be synchronously thrown with
/// that string as a message.
///
/// If the callback is called with null, the future completes with an error.
///
/// Example usage:
///
/// ```dart
/// typedef IntCallback = void Function(int result);
///
/// String _doSomethingAndCallback(IntCallback callback) {
///   Timer(new Duration(seconds: 1), () { callback(1); });
/// }
///
/// Future<int> doSomething() {
///   return _futurize(_doSomethingAndCallback);
/// }
/// ```
Future<T> _futurize<T>(_Callbacker<T> callbacker) {
  final Completer<T> completer = Completer<T>.sync();
  final String? error = callbacker((T t) {
    if (t == null) {
      completer.completeError(Exception('operation failed'));
    } else {
      completer.complete(t);
    }
  });
  if (error != null)
    throw Exception(error);
  return completer.future;
}
