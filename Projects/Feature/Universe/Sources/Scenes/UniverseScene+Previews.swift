import SpriteKit
import DomainEntity
import SharedDesignSystem

extension UniverseScene {

    /// 셰이더로 렌더링된 은하/별 프리뷰 이미지를 생성하여 sceneDelegate에 전달
    /// 2계층 캐싱: 메모리 → 디스크 → 셰이더 렌더링 순으로 조회
    func renderPreviews() {
        guard let skView = self.view, let cache = previewCache else { return }

        let sceneBg = AppColors.sceneBackground

        // ── 은하 프리뷰 ──
        let gz: CGFloat = 80
        let gCrop = CGRect(x: -gz / 2, y: -gz / 2, width: gz, height: gz)

        var currentGalaxyKeys: Set<String> = []
        for (key, galaxy) in activeGalaxies {
            currentGalaxyKeys.insert(key)

            // 메모리 캐시 히트
            if cache.galaxyImages[key] != nil { continue }
            // 디스크 캐시 히트 (메모리에 자동 로드)
            if cache.galaxyImage(for: key) != nil { continue }

            // 캐시 미스 → 셰이더 렌더링
            let container = SKNode()

            let bg = SKSpriteNode(color: sceneBg,
                                  size: CGSize(width: gz, height: gz))
            container.addChild(bg)

            let sprite = SKSpriteNode(color: .white,
                                      size: CGSize(width: gz, height: gz))
            sprite.shader = galaxyShader
            sprite.blendMode = .add
            sprite.zRotation = galaxy.tilt

            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            galaxy.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            sprite.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(Float(r), Float(g), Float(b), 1)),
                forAttribute: "a_color")
            sprite.setValue(SKAttributeValue(float: Float(galaxy.arms)),
                            forAttribute: "a_arm_count")
            sprite.setValue(SKAttributeValue(float: Float(galaxy.wind)),
                            forAttribute: "a_wind")
            sprite.setValue(SKAttributeValue(float: Float(galaxy.ellipticity)),
                            forAttribute: "a_ellipticity")
            container.addChild(sprite)

            if let texture = skView.texture(from: container, crop: gCrop) {
                let image = UIImage(cgImage: texture.cgImage())
                cache.setGalaxyImage(image, for: key)
            }
        }

        // 삭제된 은하 캐시 제거
        for key in cache.galaxyImages.keys where !currentGalaxyKeys.contains(key) {
            cache.removeGalaxy(for: key)
        }

        // ── 별 프리뷰 ──
        let sz: CGFloat = 72
        let sCrop = CGRect(x: -sz / 2, y: -sz / 2, width: sz, height: sz)

        let records = sceneDelegate?.getAllRecords() ?? []
        var currentRecordIds: Set<String> = []

        for record in records {
            currentRecordIds.insert(record.id)

            // 메모리 캐시 히트
            if cache.starImages[record.id] != nil { continue }
            // 디스크 캐시 히트 (메모리에 자동 로드)
            if cache.starImage(for: record.id) != nil { continue }

            // 캐시 미스 → 셰이더 렌더링
            let profile = record.resolvedProfile
            let container = SKNode()

            let bg = SKSpriteNode(color: sceneBg,
                                  size: CGSize(width: sz, height: sz))
            container.addChild(bg)

            let starSz: CGFloat = 36
            let sprite = SKSpriteNode(color: .white,
                                      size: CGSize(width: starSz, height: starSz))
            sprite.shader = starShader
            sprite.blendMode = .add

            let pc = profile.primaryColor
            sprite.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(Float(pc.r), Float(pc.g), Float(pc.b), 1)),
                forAttribute: "a_color")
            container.addChild(sprite)

            if let texture = skView.texture(from: container, crop: sCrop) {
                let image = UIImage(cgImage: texture.cgImage())
                cache.setStarImage(image, for: record.id)
            }
        }

        // 삭제된 레코드 캐시 제거
        for id in cache.starImages.keys where !currentRecordIds.contains(id) {
            cache.removeStar(for: id)
        }

        // delegate에 전달하여 revision 증가
        sceneDelegate?.previewImagesUpdated(
            galaxies: cache.galaxyImages,
            stars: cache.starImages
        )
    }
}
