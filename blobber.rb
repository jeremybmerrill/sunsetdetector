require 'opencv'

module Blobber
  include OpenCV

  #via https://github.com/ryanfb/ruby-opencv/blob/master/examples/houghcircle.rb

  def Blobber.ahoy_find_me_some_cirrrrcles
    original_window = GUI::Window.new "original"
    hough_window = GUI::Window.new "hough circles"


    image = IplImage::load "images/sunset.jpg"
    sunsettytemp = image.BGR2HSV

    sunsetty = sunsettytemp.in_range( CvScalar.new(0, 0, 255), CvScalar.new(47, 255, 255) )

    #gray = sunsetty.BGR2GRAY
    # graycanny = sunsetty.canny(10, #first threshold for the hysteresis procedure
    #                        100, #second threshold for the hysteresis procedure
    #                        3) #aperture size for the Sobel() operator (3 is default)
    # puts "done with canny"
    result = sunsetty.clone

    puts "detecting"
    detect = sunsetty.hough_circles(CV_HOUGH_GRADIENT, 10.0, #inverse ratio of resolution (wtf?) 
                                                  50, #minimum distance between detected centers
                                                  100,  #upper threshold for internal canny edge detector
                                                  100) #threshold for center detection. /via http://docs.opencv.org/doc/tutorials/imgproc/imgtrans/hough_circle/hough_circle.html
    puts "Found #{detect.size} circles"
    detect.each do |circle|
      puts "  #{circle.center.x},#{circle.center.y} - #{circle.radius}"
      result.circle! circle.center, circle.radius, :color => CvColor::Red, :thickness => 3
    end

    original_window.show sunsetty
    hough_window.show result
    GUI::wait_key
  end
end

Blobber::ahoy_find_me_some_cirrrrcles