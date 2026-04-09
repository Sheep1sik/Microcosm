import SwiftUI
import ComposableArchitecture
import DomainEntity
import SharedDesignSystem

struct SearchOverlayView: View {
    @Bindable var store: StoreOf<UniverseFeature>
    @FocusState.Binding var isSearchFocused: Bool

    init(store: StoreOf<UniverseFeature>, isSearchFocused: FocusState<Bool>.Binding) {
        self.store = store
        self._isSearchFocused = isSearchFocused
    }

    var body: some View {
        VStack(spacing: 0) {
            // 검색 바
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // 검색 결과
            searchResults
        }
        .background(
            Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    if isSearchFocused {
                        isSearchFocused = false
                    } else {
                        store.send(.closeSearch)
                    }
                }
        )
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.5))
            TextField(
                store.isInGalaxyDetail ? "별 검색" : "은하·별 검색",
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                )
            )
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            .focused($isSearchFocused)

            Button {
                store.send(.closeSearch)
                isSearchFocused = false
            } label: {
                Text("취소")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Results

    private var searchResults: some View {
        let galaxies = store.state.galaxyResults()
        let stars = store.state.starResults()
        let hasResults = !galaxies.isEmpty || !stars.isEmpty

        return Group {
            if !hasResults && !store.searchText.isEmpty {
                emptyResults
            } else {
                resultsList(galaxies: galaxies, stars: stars)
            }
        }
    }

    private var emptyResults: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "star.slash")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.2))
                Text("검색 결과가 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
    }

    private func resultsList(
        galaxies: [(yearMonth: String, label: String, recordCount: Int, color: Color)],
        stars: [Record]
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !galaxies.isEmpty {
                    sectionHeader("은하")
                    ForEach(galaxies, id: \.yearMonth) { galaxy in
                        Button {
                            store.send(.closeSearch)
                            store.send(.navigateToGalaxy(galaxy.yearMonth))
                        } label: { galaxyRow(galaxy) }
                        Divider().overlay(Color.white.opacity(0.08))
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
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(.top, 8)
    }

    // MARK: - Row Views

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func galaxyRow(_ galaxy: (yearMonth: String, label: String, recordCount: Int, color: Color)) -> some View {
        HStack(spacing: 14) {
            if let img = store.galaxyPreviewImages[galaxy.yearMonth] {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
            } else {
                GalaxyPreview(color: galaxy.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(galaxy.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text("\(galaxy.recordCount)개의 별")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func starRow(_ record: Record) -> some View {
        HStack(spacing: 14) {
            if let img = store.starPreviewImages[record.id] {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 36, height: 36)
            } else {
                StarPreview(
                    color: record.resolvedProfile.primaryColor.swiftUIColor,
                    seed: Double(record.id.hashValue)
                )
            }
            VStack(alignment: .leading, spacing: 3) {
                if !record.starName.isEmpty {
                    Text(record.starName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                Text(record.content)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            Text(FormatHelper.shortDate(record.createdAt))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
