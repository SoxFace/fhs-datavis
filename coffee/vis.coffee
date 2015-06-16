class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 940
    @height = 600

    # @tooltip = CustomTooltip("gates_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @year_centers = {
      "ug1": {x: @width / 4, y: @height / 2},
      "ug2": {x: (@width / 4) + 100, y: @height / 2},
      "ug3": {x: 2 * @width / 4, y: @height / 2},
      "ug4": {x: @width - 360, y: @height / 2},
      "pg": {x: @width - 260, y: @height / 2}
    }
    @class_centers = {
      "90000": {x: @width / 4, y: @height / 2},
      "150000": {x: (@width / 4) + 100, y: @height / 2},
      "500000": {x: 2 * @width / 4, y: @height / 2},
      "750000": {x: @width - 360, y: @height / 2},
      "2000000": {x: @width - 260, y: @height / 2}
    }
    @value_centers = {
      "150000": {x: @width / 4, y: @height / 2},
      "500000": {x: (@width / 4) + 100, y: @height / 2},
      "750000": {x: 2 * @width / 4, y: @height / 2},
      "2000000": {x: @width - 360, y: @height / 2}    
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale. ordinal()
      .domain(["not_valid", "ten", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred"])
      # NEW: updated color scheme to USYD
      .range(["#3C3E47", "#303f4e", "#215b7f", "#0078b2", "#7bafd8", "#d8e9fc", "#ffebeb", "#F8D0C8", "#F4AEA0", "#EF8B77", "#E64626"])

    # use the max response_rate in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.class_size))
    @radius_scale = d3.scale.pow().exponent(0.4).domain([0, max_amount]).range([0, 30])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.id
        uos_id: d.uos_id
        radius: @radius_scale(parseInt(d.class_size))
        value: d.response_rate
        name: d.academic
        org: d.unit_name
        group: d.agreement
        year: d.year_level
        class: d.class_size
        x: Math.random() * 900
        y: Math.random() * 800
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value


  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.group))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_years() && this.hide_classsize() && this.hide_responserate()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated
  # into each year. Does this by calling move_towards_year
  display_by_year: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_year(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_years() && this.hide_classsize() && this.hide_responserate()

  # move all circles to their associated @year_centers 
  move_towards_year: (alpha) =>
    (d) =>
      target = @year_centers[d.year]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display criteria
  display_years: () =>
    # Titles
    years_x = {"UG1": 100, "UG2": 280, "UG3": 460, "UG4": 610, "PG": @width - 180 }
    years_data = d3.keys(years_x)
    years = @vis.selectAll(".years")
      .data(years_data)

    years.enter().append("text")
      .attr("class", "years")
      .attr("x", (d) => years_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide year titles
  hide_years: () =>
    years = @vis.selectAll(".years").remove()


  



  






  # sets the display of bubbles to be separated
  # into each class. Does this by calling move_towards_class
  display_by_class: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_class(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_classsize() && this.hide_years() && this.hide_responserate()

  # move all circles to their associated @year_centers 
  move_towards_class: (alpha) =>
    (d) =>
      target = @class_centers[d.class]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display criteria
  display_classsize: () =>
    # Titles
    classsize_x = {"1-20": 100, "20-40": 220, "40-60": 370, "60-100": 540, "100-400": @width - 180 }
    classsize_data = d3.keys(classsize_x)
    classsize = @vis.selectAll(".classsize")
      .data(classsize_data)

    classsize.enter().append("text")
      .attr("class", "classsize")
      .attr("x", (d) => classsize_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide year titiles
  hide_classsize: () =>
    classsize = @vis.selectAll(".classsize").remove();

  # sets the display of bubbles to be separated
  # into each response rate. Does this by calling move_towards_class
  display_by_value: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_value(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_responserate() && this.hide_years() && this.hide_classsize()

  # move all circles to their associated @year_centers 
  move_towards_value: (alpha) =>
    (d) =>
      target = @value_centers[d.value]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display criteria
  display_responserate: () =>
    # Titles
    responserate_x = {"0%-19%": 70, "20%-49%": 280, "50%-79%": 520, "80%-100%": 700 }
    responserate_data = d3.keys(responserate_x)
    responserate = @vis.selectAll(".responserate")
      .data(responserate_data)

    responserate.enter().append("text")
      .attr("class", "responserate")
      .attr("x", (d) => responserate_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide response rate titles
  hide_responserate: () =>
    responserate = @vis.selectAll(".responserate").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Who:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">Unit of Study:</span><span class=\"value\"> #{data.org}</span><br/>"
    content +="<span class=\"name\">Discipline:</span><span class=\"value\"> #{data.uos_id}</span><br/>"
    content +="<span class=\"name\">My class size is:</span><span class=\"value\"> #{data.class}</span>"
    # @tooltip.showTooltip(content,d3.event)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
    # @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null  

  # DRAW CHARTS
  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()
  root.display_year = () =>
    chart.display_by_year()
  root.display_class = () =>
    chart.display_by_class()
  root.display_value = () =>
    chart.display_by_value()
  root.toggle_view = (view_type) =>
    if view_type == 'year'
      root.display_year()
    else if view_type == 'class'
        root.display_class()
    else if view_type == 'responserate'
        root.display_value()
    else
      root.display_all()

  d3.csv "data/2014_S2_USE_Success.csv", render_vis