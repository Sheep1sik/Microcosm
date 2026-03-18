import SwiftUI
import ComposableArchitecture
import DomainEntity
import DomainClient
import SharedDesignSystem

struct SearchOverlayView: View {
    let store: StoreOf<UniverseFeature>
    @FocusState.Binding var isSearchFocused: Bool

    init(store: StoreOf<UniverseFeature>, isSearchFocused: FocusState<Bool>.Binding) {
        self.store = store
        self._isSearchFocused = isSearchFocused
    }

    var body: some View {
        VStack(spacing: 0) {
            let galaxies = store.state.galaxyResults()
            let stars = store.state.starResults()
            let hasResults = !galaxies.isEmpty || !stars.isEmpty

            if !hasResults {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "star.slash").font(.title).foregroundStyle(.white.opacity(0.2))
                    Text("검색 결과가 없습니다").font(.subheadline).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !galaxies.isEmpty {
                            sectionHeader("은하")
                            ForEach(galaxies, id: \.yearMonth) { galaxy in
                                Button {
                                    store.send(.closeSearch)
                                    store.send(.navigateToGalaxy(galaxy.yearMonth))
                                } label: { galaxyRow(galaxy) }
                            }
                        }
                        if !stars.isEmpty {
                            sectionHeader(store.isInGalaxyDetail ? "별" : "별 기록")
                            ForEach(stars, id: \.id) { record in
                                Button {
                                    store.send(.closeSearch)
                                    if store.isInGalaxyDetail {
                                        store.send(.navigateToStar(record))
                                    } else {
                                        let cal = Calendar.current
                                        let y = cal.component(.year, from: record.createdAt)
                                        let m = cal.component(.month, from: record.createdAt)
                                        let key = String(format: "%04d-%02d", y, m)
                                        store.send(.navigateToGalaxyThenStar(yearMonth: key, record: record))
                                    }
                                } label: { starRow(record) }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .padding(.top, store.isInGalaxyDetail ? 100 : 52)
        .background(
            Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    if isSearchFocused {
                        isSearchFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } else { store.send(.closeSearch) }
                }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack { Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.white.opacity(0.4)); Spacer() }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)
    }

    private func galaxyRow(_ galaxy: (yearMonth: String, label: String, recordCount: Int, color: Color)) -> some View {
        HStack(spacing: 14) {
            if let img = store.galaxyPreviewImages[galaxy.yearMonth] {
                Image(uiImage: img).resizable().interpolation(.high).frame(width: 40, height: 40)
            } else { GalaxyPreview(color: galaxy.color) }
            VStack(alignment: .leading, spacing: 3) {
                Text(galaxy.label).font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                Text("\(galaxy.recordCount)개의 별").font(.caption2).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private func starRow(_ record: Record) -> some View {
        HStack(spacing: 14) {
            StarPreview(color: record.resolvedProfile.primaryColor.swiftUIColor)
            VStack(alignment: .leading, spacing: 3) {
                if !record.starName.isEmpty {
                    Text(record.starName).font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                }
                Text(record.content).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Spacer()
            Text(FormatHelper.shortDate(record.createdAt)).font(.caption2).foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }
}
