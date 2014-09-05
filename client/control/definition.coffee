###
The definition of a control.
###
class Ctrl.Definition
  ###
  Constructor.
  @param type: The type/template name.
  @param def:  An object containing the callbacks used within the control instance.
  ###
  constructor: (@type, @def = {}) ->
    # Setup initial conditions.
    self = @
    def = @def
    @def.type ?= @type
    @tmpl = tmpl = Template[@type]
    throw new Error("Template '#{ @type }' does not exist.") unless @tmpl

    # Ensure objects exist.
    def.api     ?= {}
    def.helpers ?= {}
    def.events  ?= {}

    invoke = (context, funcName, args) =>
            instance = context.__instance__
            unless instance.isDisposed
              args = [args] unless _.isArray(args)
              @def[funcName]?.apply?(instance, args)


    # INIT (invoked at construction, prior to the DOM being available).
    tmpl.created = ->
        unless @data
          throw new Error("Use {{> ctrl type='#{ def.type }' }} to insert the ctrl within a template.")

        # Retrieve the ctrl instance from the data (helpers) object,
        # then clean up the data object.
        instance = @__instance__ = @data.__instance__
        delete @data.__instance__

        # Cross reference blaze-view/instance.
        blazeView = Blaze.getView()
        blazeView.__instance__ = instance
        instance.__internal__.blazeView = blazeView

        # Store global reference to the instance.
        Ctrl.ctrls[instance.uid] = instance.ctrl

        # Retrieve a reference to the parent control.
        findParent = (blazeView) ->
                return unless blazeView
                if inst = blazeView.__instance__
                  return inst
                else
                  findParent(blazeView.parentView) # <== RECURSION.

        parent = findParent(blazeView.parentView)
        CtrlUtil.registerChild(parent, instance)

        # Invoke the "init" method on the instance.
        invoke(@, 'init')


    # CREATED (DOM Ready).
    tmpl.rendered = ->
        instance = @__instance__

        # Ensure that the control has a single root element.
        if Blaze.getView()._domrange.members.length > 1
          throw new Error("The [#{ self.type }] ctrl has more than one top-level element in the template.")

        # Add the UID attribute.
        instance.find().attr('data-ctrl-uid', instance.uid)

        # Invoke the "created" method on the instance.
        invoke(@, 'created')

        # Invoke any "ready" handlers.
        if handlers = instance.__internal__.onCreated
          handlers.invoke(instance)
          handlers.dispose()
          delete instance.__internal__.onCreated


    # DESTROYED.
    tmpl.destroyed = -> @__instance__.dispose()


    # Prepare events.
    wrapEvent = (func) -> (e, context) -> func.call(context.__instance__, e)
    def.events[key] = wrapEvent(func) for key, func of def.events
    tmpl.events(def.events)





  ###
  Inserts a new instance of the control into the DOM.
  @param el:    The element to insert into. Can be:
                - DOM element
                - jQuery element
                - String (CSS selector)
  @param args:  The named data arguments to supply to the control.
  ###
  insert: (el, args = {}) ->
    # Setup initial conditions.
    args.type = @type
    args.__insert = _.uniqueId() # Temporarily store an ID to retrieve the instance with.

    # Process the element to insert into.
    el = $(el) if _.isString(el)
    el = el[0] if el.jquery

    # Render the control.
    Blaze.renderWithData(Template.ctrl, args, el)

    # Retrieve the new instance.
    instance = Ctrl.__inserted
    delete Ctrl.__inserted
    instance

    # Finish up.
    result =
      ctrl: instance.ctrl
      ready: (func) -> instance.onCreated(func)





