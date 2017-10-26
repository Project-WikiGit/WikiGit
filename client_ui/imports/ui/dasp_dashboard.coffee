import { Template } from 'meteor/templating'

import {ReactiveVar} from 'meteor/reactive-var'

import {DASP} from '../objects/dasp.js'

import './dasp_dashboard.html'

export DASP_Address = new ReactiveVar("")

dasp = new DASP()

currentFileList = new ReactiveVar([])
currentRepoPath = new ReactiveVar("")
displayFileList = new ReactiveVar(true)
fileData = new ReactiveVar("")

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

  current_path:
    () ->
      if currentRepoPath.get().length == 0
        return '/'
      return currentRepoPath.get()
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

      dasp.initWithAddr(DASP_Address.get(), null, () ->
        dasp.lsRepo('', (error, type, result) ->
          currentFileList.set(result)
        )
      )

  'dblclick .file_item':
    (event) ->
      item = this
      if item.Name == '..'
        currentRepoPath.set(currentRepoPath.get().slice(0, currentRepoPath.get().lastIndexOf('/')))
        dasp.lsRepo(currentRepoPath.get(), (error, type, result) ->
          if error != null
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
            throw error
          if type == 'dir'
            currentRepoPath.set(currentRepoPath.get() + "/" + item.Name)
            upperDirItem =
              Name: '..'
            result.splice(0, 0, upperDirItem)
            currentFileList.set(result)
          if type == 'file'
            displayFileList.set(false)
            fileData.set(result)
        )

  'click .back_to_dir':
    (event) ->
      displayFileList.set(true)

  'click .upper_dir_btn':
    (event) ->
      currentRepoPath.set(currentRepoPath.get().slice(0, currentRepoPath.get().lastIndexOf('/')))
      dasp.lsRepo(currentRepoPath.get(), (error, type, result) ->
        if error != null
          throw error
        currentFileList.set(result)
      )
)