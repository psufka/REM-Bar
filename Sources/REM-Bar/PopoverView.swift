import SwiftUI

struct PopoverView: View {
    let score: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Score")
                .font(.headline)
            Text(score.map(String.init) ?? "?")
                .font(.system(size: 36, weight: .semibold))
        }
        .padding()
        .frame(width: 220)
    }
}
