import SwiftUI

public struct FilterSheet<T: RawRepresentable & CaseIterable & Identifiable>: View where T.RawValue == String {
    @Environment(\.presentationMode) var presentationMode
    let title: String
    let options: [T]
    @Binding var selectedOption: T
    
    public init(title: String, options: [T], selectedOption: Binding<T>) {
        self.title = title
        self.options = options
        self._selectedOption = selectedOption
    }
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(options) { option in
                    Button(action: {
                        selectedOption = option
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            if let channel = option as? Channel {
                                Image(systemName: channel.icon)
                                    .foregroundColor(channel.color)
                                    .frame(width: 24)
                                Text(channel.displayName)
                                    .foregroundColor(.primary)
                            } else if let status = option as? ConversationStatus {
                                Image(systemName: status.icon)
                                    .foregroundColor(status.color)
                                    .frame(width: 24)
                                Text(status.displayName)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            if option.id == selectedOption.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryPurple)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
