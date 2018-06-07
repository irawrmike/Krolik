//
//  DossierViewController.swift
//  Krolik
//
//  Created by Colin on 2018-06-06.
//  Copyright © 2018 Mike Stoltman. All rights reserved.
//

import UIKit

class DossierViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var agentLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    
    //MARK: Properties
    
    let networkManager = NetworkManager()
    let database = DatabaseManager()
    var currentGameId: String!
    var currentPlayer: Player!
    var playerTarget: Player!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentGameId = UserDefaults.standard.string(forKey: Game.keys.id)
        updatePlayerAndTarget()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true)
        
        // add spinner to imageView here
        
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("ERROR: No image found (DossierViewController)")
            return
        }
        
        networkManager.uploadPhoto(photo: image, path: "\(currentGameId)/\(currentPlayer.id)_target.jpg") { (url, error) in
            if error != nil {
                print(error ?? "error uploading photo in DossierViewController")
            }
            
            self.networkManager.compareFaces(target: self.playerTarget, photoURL: url.absoluteString, completion: { (isAMatch) in
                DispatchQueue.main.async {
                    if isAMatch {
                        self.killPerson()
                        let killAlert = UIAlertController(title: "Target Hit!", message: "You have just sucessfully assisinated \(self.playerTarget.nickname)!" , preferredStyle: .alert)
                        killAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(killAlert, animated: true)
                        
                    } else {
                        let failAlert = UIAlertController(title: "Target Miss!", message: "You have missed your target! Make sure you've got your positioning right and try to hit \(self.playerTarget.nickname) again", preferredStyle: .alert)
                        failAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(failAlert, animated: true)
                    }
                }
                
            })
            
        }
    }
    
    func killPerson() {
        // update target state to dead
        database.changePlayerState(gameID: UserDefaults.standard.string(forKey: Game.keys.id)!, playerID: playerTarget.id, state: Player.state.dead)
        // update player target to target's target
        database.update(playerID: currentPlayer.id, update: [Player.keys.target : playerTarget.target!])
        // update new targets assassin to current player
        database.update(playerID: playerTarget.target, update: [Player.keys.assassin : currentPlayer.id])
        updatePlayerAndTarget()
    }
    
    //MARK: Actions
    
    @IBAction func takeAimTapped(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.delegate = self
        imagePicker.cameraFlashMode = .auto
        
        // add crosshair camera overlay here
        
        present(imagePicker, animated: true)
        
    }
    
    
    func updatePlayerAndTarget() {
        // get the current player and its target from the database
        database.read(playerID: UserDefaults.standard.string(forKey: Player.keys.id)!) { (currentPlayer) in
            self.currentPlayer = currentPlayer
            
            self.database.read(playerID: currentPlayer!.target!, completion: { (playerTarget) in
                self.playerTarget = playerTarget
                
                
                // game ends if currentPlayer's target is itself
                if self.currentPlayer.id == self.playerTarget.id {
                    let gameOverAlert = UIAlertController(title: " Game Over!", message: "Game over, you WIN! Mission complete", preferredStyle: .alert)
                    gameOverAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.database.update(gameID: self.currentGameId, update: [Game.keys.state : Game.state.ended])
                    // add self as winner to game
                    let winner = currentPlayer!.nickname as String
                    self.database.update(gameID: self.currentGameId, update: [Game.keys.winner : winner])
                    print("winner is: \(winner)!")
                    // delete game and backup to history
                    self.database.delete(gameID: self.currentGameId)
                } else {
                    self.networkManager.getDataFromUrl(url: URL(string: self.playerTarget.photoURL)!) { (data, response, error) in
                        guard let imageData = data else {
                            print("bad data")
                            return
                        }
                        guard let image = UIImage(data: imageData) else {
                            print("error creating image from data")
                            return
                        }
                        DispatchQueue.main.async {
                            self.imageView.image = image
                        }
                    }
                    
                }
            })
        }
    }
}
