import SpriteKit
import DomainEntity

extension UniverseScene {

    /// 셰이더로 렌더링된 은하/별 프리뷰 이미지를 생성하여 sceneDelegate에 전달
    /// 캐싱: 이전 렌더링 키와 비교하여 변경분만 재렌더링
    func renderPreviews() {
        guard let skView = self.view else { return }

        let sceneBg = UIColor(red: 0.012, green: 0.024, blue: 0.031, alpha: 1)

        // ── 은하 프리뷰 (변경분만 재렌더링) ──
        let gz: CGFloat = 80
        let gCrop = CGRect(x: -gz / 2, y: -gz / 2, width: gz, height: gz)

        // 현재 은하 키 세트 계산
        var currentGalaxyKeys: Set<String> = []
        var newGalaxyKeys: [String] = []
        for key in activeGalaxies.keys {
            currentGalaxyKeys.insert(key)
            if cachedGalaxyPreviewImages[key] == nil {
                newGalaxyKeys.append(key)
            }
        }

        // 삭제된 은하 캐시 제거
        for key in cachedGalaxyPreviewImages.keys where !currentGalaxyKeys.contains(key) {
            cachedGalaxyPreviewImages.removeValue(forKey: key)
        }

        // 새 은하만 렌더링
        for key in newGalaxyKeys {
            guard let galaxy = activeGalaxies[key] else { continue }
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
                cachedGalaxyPreviewImages[key] = UIImage(cgImage: texture.cgImage())
            }
        }

        // ── 별 프리뷰 (변경분만 재렌더링) ──
        let sz: CGFloat = 72
        let sCrop = CGRect(x: -sz / 2, y: -sz / 2, width: sz, height: sz)

        let records = sceneDelegate?.getAllRecords() ?? []
        var currentRecordIds: Set<String> = []

        for record in records {
            currentRecordIds.insert(record.id)
            // 이미 캐시된 별은 건너뜀
            if cachedStarPreviewImages[record.id] != nil { continue }

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
                cachedStarPreviewImages[record.id] = UIImage(cgImage: texture.cgImage())
            }
        }

        // 삭제된 레코드 캐시 제거
        for id in cachedStarPreviewImages.keys where !currentRecordIds.contains(id) {
            cachedStarPreviewImages.removeValue(forKey: id)
        }

        sceneDelegate?.previewImagesUpdated(
            galaxies: cachedGalaxyPreviewImages,
            stars: cachedStarPreviewImages
        )
    }
}
