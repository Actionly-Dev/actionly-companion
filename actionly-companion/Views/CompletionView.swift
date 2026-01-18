//
//  CompletionView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct CompletionView: View {
    var viewModel: AppViewModel
    let success: Bool
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status Icon
            ZStack {
                Circle()
                    .fill(success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(success ? .green : .red)
            }

            // Title
            Text(success ? "Success!" : "Failed")
                .font(.title2)
                .fontWeight(.bold)

            // Message
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .background(Color.clear)
    }
}

#Preview {
    CompletionView(
        viewModel: AppViewModel(),
        success: true,
        message: "Successfully executed 5 keyboard shortcuts"
    )
    .frame(width: 600, height: 300)
}
