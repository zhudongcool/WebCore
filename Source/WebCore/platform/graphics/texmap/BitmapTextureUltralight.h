#pragma once

#if USE(TEXTURE_MAPPER_ULTRALIGHT)

#include "BitmapTexture.h"
#include <Ultralight/private/Canvas.h>

namespace WebCore {

class TextureMapper;
class FilterOperation;

class WEBCORE_EXPORT BitmapTextureUltralight : public BitmapTexture {
public:
    BitmapTextureUltralight(const Flags = NoFlag);

    virtual ~BitmapTextureUltralight();

    ultralight::RefPtr<ultralight::Canvas> canvas() const { return canvas_; }

    // Inherited from BitmapTexture:

    virtual void didReset() override;

    virtual IntSize size() const override { return canvas_size_; }

    virtual void updateContents(Image*, const IntRect&, const IntPoint& offset,
        UpdateContentsFlag) override;

    virtual void updateContents(const void*, const IntRect& target,
        const IntPoint& offset, int bytesPerLine, UpdateContentsFlag) override;

    virtual bool isValid() const override { return !!canvas_; }

    virtual PassRefPtr<BitmapTexture> applyFilters(TextureMapper&,
        const FilterOperations&) override;

protected:
    ultralight::RefPtr<ultralight::Canvas> canvas_;
    IntSize canvas_size_;
};

}  // namespace WebCore

#endif // USE(TEXTURE_MAPPER_ULTRALIGHT)
