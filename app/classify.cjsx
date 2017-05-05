React = require 'react/addons'
cx = React.addons.classSet

Annotation = require './annotation/annotation'
SlideTutorial = require './slideTutorial'
Guide = require './guide'

Subject = require 'zooniverse/models/subject'
Favorite = require 'zooniverse/models/favorite'
Classification = require 'zooniverse/models/classification'
User = require 'zooniverse/models/user'

steps = require './lib/steps'

outOfSubjectsMessage = '''
  <h3>We seem to be out of data!<h3>

  <p>Please try refreshing the page. If you get this message again,
  we unfortunately don't have any more videos to show you right now!
  Either all current videos have been explored, or you personally
  may have explored every available video. We should have more
  data for you fairly soon, so don't forget about us!</p>

  <p>In the meantime, you can continue working on this project
  by helping us ID and name individual chimps on <a href="http://talk.chimpandsee.org" target="_blank">Chimp & See Talk</a>.
  Or check out any of our dozens of other Zooniverse projects at
  <a href="https://www.zooniverse.org/" target="_blank">zooniverse.org</a>. Thanks!</p>
'''

fetchFailMessage = '''
  <p>Hey Chimp & See explorer—something's gone wrong!
  Our system is having trouble finding a video for you right now. We're sorry about that!</p>

  <p>Let us know about this bug on the <a href="http://talk.chimpandsee.org/#/boards/BCP0000008" target="_blank">Technical Support</a>
  board on C&S Talk, and we'll try to get it fixed as soon as possible. Thanks for your help, efforts, and patience!</p>
'''

module?.exports = React.createClass
  displayName: 'Classify'

  wrapper: null
  body: null
  html: null
  main: null

  getInitialState: ->
    video: null
    previews: null
    location: null
    classification: null
    guideIsOpen: false
    tutorialIsOpen: false
    tutorialType: null
    skipImages: false
    srcWidth: null
    toggleSkip: false
    noSubjects: false

  componentDidMount: ->
    Subject.on 'select', @onSubjectSelect
    Subject.on 'no-more', @onNoSubjects
    Subject.on 'fetch-fail', @onSubjectFetchFail
    Subject.next()

    # Grabbing DOM element outside of React components to be able to move everything to the right including top bar
    @wrapper = document.getElementById('wrapper')
    @body = document.getElementsByTagName('body')[0]
    @html = document.getElementsByTagName('html')[0]
    @main = document.getElementsByClassName('main')[0]

    if User.current is null
      @openTutorial 'general'

    @setInitialSkipPreference(@props)

  componentWillReceiveProps: (nextProps) ->
    if nextProps.user isnt @props.user
      @setInitialSkipPreference(nextProps)

    if nextProps.user is null
      @setState skipImages: false
      @refs.skipCheckbox?.getDOMNode().checked = false

    unless nextProps.user?.classification_count > 0
      @openTutorial 'general'

  componentWillUnmount: ->
    Subject.off 'select', @onSubjectSelect
    Subject.off 'no-more', @onNoSubjects
    Subject.off 'fetch-fail', @onSubjectFetchFail
    @removeClassesForGuide()

  onSubjectSelect: (e, subject) ->
    randomInt = if subject.location.previews.length is 2 then Math.round(Math.random()) else Math.round(Math.random() * (2 - 0)) + 0
    previews = subject.location.previews[randomInt]

    if window.location.hostname is "www.chimpandsee.org"
      previews = previews.map (preview, i) ->
        preview = preview.replace("http", "https")

    @setState({
      video: subject.location.standard
      previews: previews
      location: subject.group.name
      classification: new Classification {subject}
    }, => @onSubjectUpdate(randomInt))

  onSubjectUpdate: (integer) ->
    @state.classification.annotate previewsSet: integer
    @checkSrcWidth()

  onSubjectFetchFail: ->
    @setState({
      video: null
      previews: null
      location: null
      classification: null
      noSubjects: true
    }, ->
      unless Subject.count() is 0
        @refs.statusMessage.getDOMNode().innerHTML = fetchFailMessage
      else
        @refs.statusMessage.getDOMNode().innerHTML = outOfSubjectsMessage
    )

  onNoSubjects: ->
    @setState({
      video: null
      previews: null
      location: null
      classification: null
      noSubjects: true
    }, -> @refs.statusMessage.getDOMNode().innerHTML = outOfSubjectsMessage)

  checkSrcWidth: ->
    image = new Image()
    image.src = @state.previews[0]
    image.onload = =>
      @setState srcWidth: image.naturalWidth

  toggleGuide: (e) ->
    if @state.guideIsOpen is false
      @refs.guide.getDOMNode().scrollTop = 0
      @setState guideIsOpen: true
      @addClassesForGuide()
    else
      @onClickClose()

  onClickClose: ->
    @setState guideIsOpen: false
    @removeClassesForGuide()

  addClassesForGuide: ->
    @wrapper.classList.add 'push-right'
    @body.classList.add 'no-scroll'
    @main.classList.add 'scroll' if window.innerWidth > 400

    #For iOS Safari
    @html.style.overflow = 'hidden' if window.innerWidth < 401
    @body.style.overflow =  'hidden' if window.innerWidth < 401

  removeClassesForGuide: ->
    @wrapper.classList.remove 'push-right'
    @body.classList.remove 'no-scroll'
    @main.classList.remove 'scroll' if window.innerWidth > 400

    #For iOS Safari
    @html.style.overflow = 'initial' if window.innerWidth < 401
    @body.style.overflow = 'initial' if window.innerWidth < 401

  openTutorial: (type) ->
    @setState
      tutorialIsOpen: true
      tutorialType: type

  closeTutorial: ->
    @setState tutorialIsOpen: false

  onClickSkipCheckbox: (e) ->
    checkbox = e.target

    if @props.user?
      @setUserSkipPreference(checkbox.checked)
    else
      @setState skipImages: checkbox.checked

  enableSkip: ->
    @setState toggleSkip: false

  disableSkip: ->
    @setState toggleSkip: true

  setInitialSkipPreference: (prop) ->
    if prop.user?.preferences?.chimp?.skip_first_step is "true"
      @setState skipImages: true
      @refs.skipCheckbox?.getDOMNode().checked = true

  setUserSkipPreference: (preference) ->
    User.current?.setPreference 'skip_first_step', preference, @setState skipImages: preference

  render: ->
    classifyClasses = cx
      'classify': true
      'content': true
      'open-guide': @state.guideIsOpen is true

    hiddenChimpClasses = cx
      'hide': @state.previews is null
      'hidden-chimp-container': true

    skipCheckboxDisabled = true if @state.toggleSkip is true

    <div className={classifyClasses}>
      <Guide ref="guide" onClickClose={@onClickClose} guideIsOpen={@state.guideIsOpen} />
      {unless @state.location is null
        <div className="location-container">
          <div>
            <p><span className="bold">Site:</span> {@state.location}</p>
            <div className="btn-container">
              <button className="tutorial-btn" onClick={@openTutorial.bind(null, "general")}>Tutorial</button>
              <a href="http://talk.chimpandsee.org/#/boards/BCP0000007" target="faq-link" className="faq-link"><button className="faq-btn">FAQs</button></a>
              <label className="skip-checkbox-label" htmlFor="skip-checkbox">
                <input
                  ref="skipCheckbox"
                  defaultChecked={@props.user?.preferences?.chimp?.skip_first_step is "true"}
                  type="checkbox"
                  id="skip-checkbox"
                  onClick={@onClickSkipCheckbox}
                  disabled={skipCheckboxDisabled}
                  className={"disabled" if skipCheckboxDisabled}
                />
                  Skip images?
              </label>
            </div>
          </div>
        </div>
      }
      {unless @state.previews is null and @state.video is null
        <Annotation
          video={@state.video}
          previews={@state.previews}
          classification={@state.classification}
          toggleGuide={@toggleGuide}
          guideIsOpen={@state.guideIsOpen}
          tutorialType={@state.tutorialType}
          openTutorial={@openTutorial}
          user={@props.user}
          location={@state.location}
          skipImages={@state.skipImages}
          srcWidth={@state.srcWidth}
          enableSkip={@enableSkip}
          disableSkip={@disableSkip}
        />
      }
      {if @state.noSubjects
        <div className="status-message" ref="statusMessage"></div>}
      <SlideTutorial tutorialIsOpen={@state.tutorialIsOpen} closeTutorial={@closeTutorial} tutorialType={@state.tutorialType} />
      <div className={hiddenChimpClasses}><img className="hidden-chimp" src="./assets/hidden-chimp.png" alt="" /></div>
    </div>
