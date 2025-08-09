# Wooden Border Assets

This folder contains the wooden texture assets for your app's border frame.

## Required Assets

### Simple Implementation (Recommended)
Place a wooden texture image file here:
- `wood_texture.png` - A seamless wooden texture that will be used as the border background

### Advanced Implementation (Optional)
For more detailed borders, you can create separate pieces:
- `wood_border_horizontal.png` - Horizontal border pieces (top/bottom)
- `wood_border_vertical.png` - Vertical border pieces (left/right)
- `wood_corner_top_left.png` - Top-left corner piece
- `wood_corner_top_right.png` - Top-right corner piece
- `wood_corner_bottom_left.png` - Bottom-left corner piece
- `wood_corner_bottom_right.png` - Bottom-right corner piece

## Usage

The wooden border is automatically applied to your entire app. You can customize it by:

1. **Changing the border width**: Modify `borderWidth` parameter in `WoodenBorderWrapper`
2. **Adjusting corner radius**: Modify `cornerRadius` parameter in `WoodenBorderWrapper`
3. **Switching implementations**: Change from `WoodenBorderWrapper` to `DetailedWoodenBorderWrapper` in `main.dart` for more detailed borders

## Current Implementation

Your app currently uses the simple `WoodenBorderWrapper` which creates a wooden frame around all your screens using a single texture file.

## Asset Requirements

- **Size**: 512x512px minimum for good quality
- **Format**: PNG with transparency support (if needed)
- **Seamless**: Make sure textures tile seamlessly for best appearance
- **Resolution**: Provide @2x and @3x versions for different screen densities if desired