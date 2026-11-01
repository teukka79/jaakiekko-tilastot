import SwiftUI

// MARK: - NHL-ottelun lisäkortit (erätilanne, tilastovertailu, jäähyt, rankkarit, tähdet)

/// Maalirivin tulos- ja videopainikkeen väri (pehmeä syaani).
let goalAccent = Theme.cyan
/// Vierasjoukkueen väri: palkit ja tekstit (vaaleampi indigo luettavuuden vuoksi).
let awayAccent = Theme.indigo
let awayText = Color(hex: 0xA5A8FF)

func nhlPeriodTitle(_ p: Int) -> String {
    switch p {
    case 1, 2, 3: return "\(p). erä"
    case 4: return "Jatkoaika"
    default: return "Jatkoaika \(p - 3)"
    }
}

struct NHLPeriodCard: View {
    let home: String
    let away: String
    let ex: NHLExtras

    private func cell(_ v: Int?, bold: Bool = false) -> some View {
        Text(v.map(String.init) ?? "–")
            .font(.system(size: 12, weight: bold ? .bold : .regular).monospacedDigit())
            .foregroundStyle(bold ? Theme.amber : Theme.text)
            .frame(width: 38, alignment: .trailing)
    }

    private func sum(_ f: (NHLPeriodLine) -> Int?) -> Int {
        ex.periods.filter { $0.label != "RL" }.reduce(0) { $0 + (f($1) ?? 0) }
    }

    private func row(_ team: String, goals: Bool, home isHome: Bool) -> some View {
        HStack(spacing: 0) {
            TeamLogoView(team: team, size: 30).frame(width: 32, height: 30)
            Text(team).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                .lineLimit(1).padding(.leading, 6)
            Spacer(minLength: 0)
            ForEach(ex.periods) { p in
                cell(goals ? (isHome ? p.hGoals : p.aGoals) : (isHome ? p.hShots : p.aShots))
            }
            if goals {
                cell(ex.totalGoals.map { isHome ? $0.h : $0.a } ?? sum { isHome ? $0.hGoals : $0.aGoals }, bold: true)
            } else {
                cell(sum { isHome ? $0.hShots : $0.aShots }, bold: true)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 3)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(ex.periods) { p in
                Text(p.label).frame(width: 38, alignment: .trailing)
            }
            Text("Yht").frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
        .padding(.horizontal, 12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel("Erätilanne").padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
            header
            row(home, goals: true, home: true)
            row(away, goals: true, home: false)
            if ex.periods.contains(where: { $0.hShots != nil || $0.aShots != nil }) {
                Text("Laukaukset").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 12).padding(.top, 6)
                row(home, goals: false, home: true)
                row(away, goals: false, home: false)
            }
        }
        .padding(.bottom, 8)
        .glassCard(radius: 12)
    }
}

struct NHLStatsCard: View {
    let home: String
    let away: String
    let stats: [NHLStatLine]

    private func bar(_ l: NHLStatLine) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(l.home).font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(l.hv > l.av ? Theme.amber : Theme.text)
                Spacer()
                Text(l.label).font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Text(l.away).font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(l.av > l.hv ? Theme.amber : Theme.text)
            }
            GeometryReader { geo in
                let total = l.hv + l.av
                let w = max(geo.size.width - 4, 0)
                let hw = total > 0 ? w * CGFloat(l.hv / total) : w / 2
                HStack(spacing: 4) {
                    Capsule().fill(l.hv >= l.av ? Theme.amber : Color.white.opacity(0.14)).frame(width: hw)
                    Capsule().fill(l.av >= l.hv ? Theme.amber : Color.white.opacity(0.14)).frame(width: max(w - hw, 0))
                }
            }
            .frame(height: 6)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("Tilastovertailu").padding(.top, 14)
            ForEach(stats) { bar($0) }
        }
        .padding(.horizontal, 16).padding(.bottom, 18)
        .glassCard(radius: 12)
    }
}

struct NHLPenaltyCard: View {
    let home: String
    let away: String
    let penalties: [NHLPenaltyLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Jäähyt").padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            ForEach(Array(penalties.enumerated()), id: \.element.id) { idx, p in
                VStack(alignment: .leading, spacing: 0) {
                    if idx == 0 || penalties[idx - 1].period != p.period {
                        Text(nhlPeriodTitle(p.period)).font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.muted).padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)
                    }
                    HStack(spacing: 10) {
                        Text(String(format: "%d:%02d", p.seconds / 60, p.seconds % 60))
                            .font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted)
                            .frame(width: 44, alignment: .leading)
                        TeamLogoView(team: p.home ? home : away, size: 34).frame(width: 36, height: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.player).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                            Text(p.reason).font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        Text("\(p.minutes) min").font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(p.minutes >= 5 ? Theme.red : Theme.amber)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)
                }
            }
        }
        .padding(.bottom, 6)
        .glassCard(radius: 12)
    }
}

struct NHLShootoutCard: View {
    let home: String
    let away: String
    let list: [NHLShootoutLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Rankkarit").padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            ForEach(Array(list.enumerated()), id: \.element.id) { idx, s in
                HStack(spacing: 10) {
                    Text("\(idx + 1).").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted)
                        .frame(width: 28, alignment: .leading)
                    TeamLogoView(team: s.home ? home : away, size: 34).frame(width: 36, height: 34)
                    Text(s.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                    Text(s.scored ? "maali" : "torjuttu")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(s.scored ? Theme.green : Theme.muted)
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
            }
        }
        .padding(.bottom, 6)
        .glassCard(radius: 12)
    }
}

struct NHLStarsCard: View {
    let home: String
    let away: String
    let stars: [NHLStarLine]
    let goalies: [NHLGoalieLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !stars.isEmpty {
                SectionLabel("Ottelun tähdet").padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                ForEach(stars) { s in
                    HStack(spacing: 10) {
                        Text(String(repeating: "★", count: max(1, 4 - s.star)))
                            .font(.system(size: 11)).foregroundStyle(Theme.amber)
                            .frame(width: 44, alignment: .leading)
                        if let h = s.home {
                            TeamLogoView(team: h ? home : away, size: 34).frame(width: 36, height: 34)
                        }
                        Text(s.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                        Text(s.detail).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)
                }
            }
            if !goalies.isEmpty {
                SectionLabel("Maalivahdit").padding(.horizontal, 12).padding(.top, stars.isEmpty ? 10 : 12).padding(.bottom, 4)
                ForEach(goalies) { g in
                    HStack(spacing: 10) {
                        TeamLogoView(team: g.home ? home : away, size: 34).frame(width: 36, height: 34)
                        Text(g.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                        Text(g.line).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)
                }
            }
        }
        .padding(.bottom, 8)
        .glassCard(radius: 12)
    }
}

// MARK: - Maalivideo ohjelman sisällä

import WebKit

struct VideoItem: Identifiable { let id = UUID(); let url: URL }

private struct InlineWebView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.load(URLRequest(url: url))
        return v
    }
    func updateNSView(_ v: WKWebView, context: Context) {}
}

struct VideoSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Maalin video").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
            }
            .padding(12)
            InlineWebView(url: url)
        }
        .frame(width: 800, height: 520)
        .background(AppBackground())
    }
}


// MARK: - Tulospilleri

/// Tulos pillerinä: voittavan joukkueen luku korostetaan (koti lasinsininen, vieras indigo).
struct ScorePill: View {
    enum Size { case large, medium, small }
    let home: Int?
    let away: Int?
    var size: Size = .medium
    /// true: molemmat luvut keltaisella, voittajan tausta täytetty (otsikko); false: joukkueiden värit.
    var amber = false

    private var fontSize: CGFloat { size == .large ? 22 : (size == .medium ? 16 : 13) }
    private var padH: CGFloat { size == .large ? 14 : (size == .medium ? 10 : 7) }
    private var padV: CGFloat { size == .large ? 5 : (size == .medium ? 4 : 2) }
    private var radius: CGFloat { size == .large ? 12 : (size == .medium ? 9 : 7) }

    var body: some View {
        HStack(spacing: 0) {
            if let h = home, let a = away {
                Text("\(h)").padding(.horizontal, padH).padding(.vertical, padV)
                    .foregroundStyle(amber ? Theme.amber : (h > a ? goalAccent : Theme.muted))
                    .background(h > a ? (amber ? Theme.amber : goalAccent).opacity(amber ? 0.22 : 0.2) : Color.clear)
                Text("\(a)").padding(.horizontal, padH).padding(.vertical, padV)
                    .foregroundStyle(amber ? Theme.amber : (a > h ? awayText : Theme.muted))
                    .background(a > h ? (amber ? Theme.amber.opacity(0.22) : awayAccent.opacity(0.3)) : Color.clear)
            } else {
                Text("–").padding(.horizontal, padH + 6).padding(.vertical, padV).foregroundStyle(Theme.muted)
            }
        }
        .font(.system(size: fontSize, weight: .heavy).monospacedDigit())
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
