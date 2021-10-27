//
//  ButtonExt.swift
//  Image Blur Skeleton
//
//  Created by Ionut Ciovica on 26/10/2021.
//

import UIKit

extension UIButton {
    func adjustButton(_ button: UIButton) {
        button.layer.shadowOffset = CGSize(width: 5, height: 5)
        button.layer.shadowRadius = 5
        button.layer.shadowOpacity = 0.5
        button.tintColor = .blue3
    }
}
