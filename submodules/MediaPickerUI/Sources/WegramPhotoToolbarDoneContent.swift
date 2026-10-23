import UIKit
import Display
import ComponentFlow
import BundleIconComponent

func wegramPhotoToolbarDoneContent(iconName: String, title: String?, fontSize: CGFloat = 17) -> AnyComponent<Empty> {
    let item: AnyComponentWithIdentity<Empty>
    if let title {
        item = AnyComponentWithIdentity(id: "text", component: AnyComponent(Text(text: title, font: Font.medium(fontSize), color: .white)))
    } else {
        item = AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: iconName, tintColor: .white)))
    }
    // ComponentView retains its concrete view type as the toolbar gains its real size or rotates.
    return AnyComponent(ZStack<Empty>([item]))
}
