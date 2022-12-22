//
//  VerticalLeftAlignedLayout.swift
//

import AppKit

class VerticalLeftAlignedLayout: BoundsResizableLayout {

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        let inherited = super.layoutAttributesForElements(in: rect).copy()
        
        for attributes in inherited where attributes.representedElementCategory == .item {
            if let indexPath = attributes.indexPath, let adjustedFrame = layoutAttributesForItem(at: indexPath)?.frame {
                attributes.frame = adjustedFrame
            }
        }
        return inherited
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard let current = super.layoutAttributesForItem(at: indexPath)?.copy()
            as? NSCollectionViewLayoutAttributes else { return nil }
        
        var describesFirstItemInLine: Bool {
            guard indexPath.item > 0 else { return true }
            guard let preceding = super.layoutAttributesForItem(at: indexPath.preceding) else { return true }
            return !isFrame(for: current, inSameLineAsFrameFor: preceding)
        }

        if describesFirstItemInLine {
            current.frame.origin.x = inset(forSection: indexPath.section).left
        } else {
            let offset = minimumInteritemSpacing(forSection: indexPath.section)
            if let preceding = layoutAttributesForItem(at: indexPath.preceding) {
                current.frame.origin.x = preceding.frame.maxX + offset
            }
        }

        return current
    }

    private func isFrame(for firstItemAttributes: NSCollectionViewLayoutAttributes, inSameLineAsFrameFor secondItemAttributes: NSCollectionViewLayoutAttributes) -> Bool {
        precondition(firstItemAttributes.indexPath?.section == secondItemAttributes.indexPath?.section)
        guard let section = firstItemAttributes.indexPath?.section else { return false }

        if firstItemAttributes.size.height == 0 || secondItemAttributes.frame.size.height == 0 { return false }
        
        let sectionInset = inset(forSection: section)
        var availableContentWidth: CGFloat? {
            guard let collectionViewWidth = collectionView?.frame.size.width else { return nil }
            return collectionViewWidth - sectionInset.left - sectionInset.right
        }
        guard let lineWidth = availableContentWidth else { return false }

        let lineFrame = CGRect(x: sectionInset.left, y: firstItemAttributes.frame.origin.y,
                               width: lineWidth, height: firstItemAttributes.frame.size.height)
        
        return lineFrame.intersects(secondItemAttributes.frame)
    }

    private func minimumInteritemSpacing(forSection section: Int) -> CGFloat {
        guard let collectionView = self.collectionView else { return minimumInteritemSpacing}

        let delegate = collectionView.delegate as? NSCollectionViewDelegateFlowLayout
        return delegate?.collectionView?(collectionView, layout: self, minimumInteritemSpacingForSectionAt: section) ?? minimumInteritemSpacing
    }

    private func inset(forSection section: Int) -> NSEdgeInsets {
        guard let collectionView = self.collectionView else { return sectionInset }

        let delegate = collectionView.delegate as? NSCollectionViewDelegateFlowLayout
        return delegate?.collectionView?(collectionView, layout: self, insetForSectionAt: section) ?? sectionInset
    }
}

fileprivate extension Array where Element == NSCollectionViewLayoutAttributes {
    
    func copy() -> [NSCollectionViewLayoutAttributes] {
        map { $0.copy() as! NSCollectionViewLayoutAttributes }
    }
}

fileprivate extension IndexPath {
    
    var preceding: IndexPath {
        precondition(item > 0)
        return IndexPath(item: item - 1, section: section)
    }
}
