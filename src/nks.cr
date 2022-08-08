require "crsfml"

window = SF::RenderWindow.new(SF::VideoMode.new(1000, 1000), title: "Novika Sketchbook")
window.framerate_limit = 60

shape = SF::RectangleShape.new
shape.size = SF.vector2(50, 50)
shape.fill_color = SF::Color::Black

while window.open?
  while event = window.poll_event
    case event
    when SF::Event::Closed
      window.close
    when SF::Event::Resized
      window.view = SF::View.new(SF.float_rect(0, 0, event.width, event.height))
    else
      puts "Event: #{event}"
    end
  end

  window.clear(SF::Color::White)
  window.draw(shape)
  window.display
end
