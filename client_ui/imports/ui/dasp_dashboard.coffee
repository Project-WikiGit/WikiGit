import { Template } from 'meteor/templating'

import {ReactiveVar} from 'meteor/reactive-var'

import {DASP} from '../objects/dasp.js'

import './dasp_dashboard.html'

export DASP_Address = new ReactiveVar("")

#Shared variables
dasp = new DASP()

showToastMsg = (msg) ->
  snackbarContainer = document.querySelector('#status_toast')
  snackbarContainer.MaterialSnackbar.showSnackbar({message: msg})
  return

copyTextToClipboard = (text) ->
  textArea = document.createElement("textarea")
  # *** This styling is an extra step which is likely not required. ***
  # Why is it here? To ensure:
  # 1. the element is able to have focus and selection.
  # 2. if element was to flash render it has minimal visual impact.
  # 3. less flakyness with selection and copying which **might** occur if
  #    the textarea element is not visible.
  # The likelihood is the element won't even render, not even a flash,
  # so some of these are just precautions. However in IE the element
  # is visible whilst the popup box asking the user for permission for
  # the web page to copy to the clipboard.

  # Place in top-left corner of screen regardless of scroll position.
  textArea.style.position = 'fixed'
  textArea.style.top = 0
  textArea.style.left = 0

  # Ensure it has a small width and height. Setting to 1px / 1em
  # doesn't work as this gives a negative w/h on some browsers.
  textArea.style.width = '2em'
  textArea.style.height = '2em'

  # We don't need padding, reducing the size if it does flash render.
  textArea.style.padding = 0

  # Clean up any borders.
  textArea.style.border = 'none'
  textArea.style.outline = 'none'
  textArea.style.boxShadow = 'none'

  # Avoid flash of white box if rendered for any reason.
  textArea.style.background = 'transparent'


  textArea.value = text

  document.body.appendChild(textArea)

  textArea.select()

  try
    successful = document.execCommand('copy')
    msg = if successful then 'Copied Clone Address to Clipboard' else 'Oops, unable to copy'
    showToastMsg(msg)
  catch err
    showToastMsg('Oops, unable to copy')


  document.body.removeChild(textArea)
  return

#Repo tab variables
currentFileList = new ReactiveVar([])
currentRepoPath = new ReactiveVar("")
displayFileList = new ReactiveVar(true)
fileData = new ReactiveVar("")
fileName = new ReactiveVar("")

#Member tab variables
memberList = new ReactiveVar([])
isSigningUp = new ReactiveVar(false)
signUpType = new String()
SIGNUP_STATUS_SHOWTIME = 3000

Template.repo_tab.helpers(
  ls_file:
    () ->
      return currentFileList.get()

  display_file_list:
    () ->
      return displayFileList.get()

  file_data:
    () ->
      return fileData.get()

  file_name:
    () ->
      return fileName.get()

  file_download_url:
    () ->
      return "https://gateway.ipfs.io/ipfs/#{dasp.repoIPFSHash}#{currentRepoPath.get()}/#{fileName.get()}"

  current_path:
    () ->
      if currentRepoPath.get().length == 0
        return '/'
      return currentRepoPath.get()
)

Template.members_tab.helpers(
  member_list:
    () ->
      return memberList.get()

  not_signing_up:
    () ->
      return !isSigningUp.get()
)

Template.body.events(
  'submit .dasp_addr_input':
    (event) ->
      # Prevent default browser form submit
      event.preventDefault()
      # Get value from form element
      target = event.target
      text = target.dasp_addr.value

      DASP_Address.set(text)

      target.dasp_addr.value = ''

      dasp.initWithAddr(DASP_Address.get(), null, (error) ->
        if error != null
          showToastMsg('Ethereum Connection Error')
          throw error
        dasp.lsRepo('', (error, type, result) ->
          if error != null
            showToastMsg('List Repo Error')
            throw error
          currentFileList.set(result)
        )
        dasp.lsMembers((error, result) ->
          if error != null
            showToastMsg('Load Member Data Error')
            throw error
          memberList.set(result)
        )
      )
)

Template.repo_tab.events(
  'dblclick .file_item':
    (event) ->
      item = this
      if item.Name == '..'
        currentRepoPath.set(currentRepoPath.get().slice(0, currentRepoPath.get().lastIndexOf('/')))
        dasp.lsRepo(currentRepoPath.get(), (error, type, result) ->
          if error != null
            showToastMsg('List Repo Error')
            throw error
          if currentRepoPath.get().length != 0
            upperDirItem =
              Name: '..'
            result.splice(0, 0, upperDirItem)
          currentFileList.set(result)
          return
        )
      else
        dasp.lsRepo("#{currentRepoPath.get()}/#{item.Name}", (error, type, result) ->
          if error != null
            showToastMsg('List Repo Error')
            throw error
          if type == 'dir'
            currentRepoPath.set(currentRepoPath.get() + "/" + item.Name)
            upperDirItem =
              Name: '..'
            result.splice(0, 0, upperDirItem)
            currentFileList.set(result)
          if type == 'file'
            displayFileList.set(false)
            fileName.set(item.Name)
            fileData.set(result)
        )

  'click .back_to_dir':
    (event) ->
      displayFileList.set(true)
      fileData.set("")

  'click .upper_dir_btn':
    (event) ->
      currentRepoPath.set(currentRepoPath.get().slice(0, currentRepoPath.get().lastIndexOf('/')))
      dasp.lsRepo(currentRepoPath.get(), (error, type, result) ->
        if error != null
          showToastMsg('List Repo Error')
          throw error
        currentFileList.set(result)
      )

  'click .clone_repo_btn':
    (event) ->
      copyTextToClipboard("https://gateway.ipfs.io/ipfs/#{dasp.repoIPFSHash}/repo.git")
)

Template.members_tab.events(
  'click .signup_freelancer':
    (event) ->
      isSigningUp.set(true)
      signUpType = 'freelancer'

  'click .signup_shareholder':
    (event) ->
      isSigningUp.set(true)
      signUpType = 'shareholder'

  'click .cancel_signup':
    (event) ->
      isSigningUp.set(false)

  'click .refresh_member_list':
    (event) ->
      dasp.lsMembers((error, result) ->
        console.log(error)
        if error != null
          showToastMsg('Load Member Data Error')
          throw error
        memberList.set(result)
      )

  'submit .signup_username':
    (event) ->
      event.preventDefault()

      target = event.target
      userName = target.username.value

      dasp.signUp(signUpType, userName, (error) ->
        if error != null
          showToastMsg('Sign Up Error')
          throw error
        else
          dasp.lsMembers((error, result) ->
            if error != null
              showToastMsg('Sign Up Error')
              throw error
            else
              memberList.set(result)
              showToastMsg('Sign Up Success')
              throw error
          )
      )
      isSigningUp.set(false)
      target.username.value = ''

)