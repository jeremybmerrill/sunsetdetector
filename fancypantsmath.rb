# encoding: utf-8

##### CALCULUS 101 ########
#in general.
#so given f(x) = cos(2x)
# df/dx = -2sin(2x)
# then ddf/dx/dx = d/dx d/dx cos(x) = -4cos(2x)
#but various constants and things having been flattened, f is changing most rapidly when f'' = 0. (when f'' is )

#e.g. truncated_coeff = => [1.751297768, 0, 0.9489264930533873, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
#somehow, transform this into a (differentiable) function.
#differentiate that function and, based on the value as of the most recent sunset (e.g. if slope ought to be at its highest.), tweet or not.

require 'gsl'

module FancyPantsMath
  DC_CONSTANT = 0.20
  IMAGES_TO_CONSIDER = 16
  MINIMUM_SUNSETTINESS = 0.2

  ##
  # Returns the index value of a sunsetty image, if one exists in the most recent 10 images.
  # If more than one image crosses zero in the right way, return the one with the highest value.
  ##
  def FancyPantsMath.do_some_calculus(truncated_data)

    return false if truncated_data.size < IMAGES_TO_CONSIDER #short-circuit if there are too few images to consider

    coeff = GSL::Vector.alloc(truncated_data).fft.to_a
    dc_value = coeff.first #y-intercept, whatever.
    coeff_rest = coeff[1..-1]


    largest_coeff = coeff_rest.max

    index_of_largest_coeff = coeff_rest.index(largest_coeff) + 1 # +1 because we want its index with the dc_value as index 0.

    period = coeff.size

    c = largest_coeff
    k = index_of_largest_coeff

    #showing my work!
    #prettier functions
    sunsettiness_time = "#{dc_value}+#{c}*cos( (#{k}*2π*x / #{period})"
    first_derivative_sunsettiness_wrt_time = "-#{c}*(#{k}*2π/#{period})*sin(#{k}*2π*x / #{period})"
    second_derivative_sunsettiness_wrt_time = "-#{c}*(#{k}*2π/#{period})^2*cos(#{k}*2π*x / #{period})"

    #actual functions
    sunsettiness = lambda{|x| dc_value + largest_coeff * Math.cos( k * 2 * Math::PI * x / period )}
    first_derivative = lambda{|x| -1 * c * k * 2 * Math::PI / period * Math.sin(k * 2 * Math::PI * x / period)}
    second_derivative = lambda{|x|  -1 * c * ((k * 2 * Math::PI / period) ** 2) * Math.cos(k * 2 * Math::PI * x / period)}



    if dc_value < DC_CONSTANT
      puts "DC value too low: dc_value"
      return false
    end
    
    who_crosses_zero = truncated_data[-IMAGES_TO_CONSIDER..-1].each_with_index.map do |datum, index|
      if [0, 1, 2, IMAGES_TO_CONSIDER - 1, IMAGES_TO_CONSIDER - 2].include? index
        false 
      else 
        #make sure this isn't a momentary blip.

        image_is_sunsetty = truncated_data[-IMAGES_TO_CONSIDER + index] > MINIMUM_SUNSETTINESS

        photo_itself_less_than_zero = second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index) < 0.0
        previous_photos_greater_than_zero = [second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index - 3) >= 0.0,
                                              second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index - 2) >= 0.0,
                                              second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index - 1) >= 0.0]
        following_photos_less_than_zero =  [second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index + 1) < 0.0,
                                            second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index + 2) < 0.0,
                                            second_derivative.call(truncated_data.size() - IMAGES_TO_CONSIDER + index + 3) < 0.0]

        photo_itself_less_than_zero && previous_photos_greater_than_zero.count(true) >= 2 && following_photos_less_than_zero.count(true) >= 2
      end
    end

    puts who_crosses_zero.inspect

    if who_crosses_zero.count(true) == 0
      puts "DC value okay, but nothing crossed zero"
      return false
    elsif who_crosses_zero.count(true) == 1
      index_to_tweet = who_crosses_zero.index(true)
    else
      who_crosses_zero_amts = who_crosses_zero.each_with_index.map{|val, index| val ? truncated_data[truncated_data.size() - IMAGES_TO_CONSIDER + index] : 0.0}
      index_to_tweet = who_crosses_zero_amts.index(who_crosses_zero_amts.max)
    end
    puts ["DC: " + dc_value.to_s, "Sunsettiness: " + truncated_data[-IMAGES_TO_CONSIDER + index_to_tweet].to_s ].inspect

    if truncated_data[-IMAGES_TO_CONSIDER + index_to_tweet] > 0.0
      return index_to_tweet 
    else
      return false
    end

    #older stuff to keep around for reference
    # accel_crosses_zero = second_derivative.call(truncated_data.size()-look_back_amount-2) < 0.0 && (second_derivative.call(truncated_data.size() -look_back_amount-1) < 0.0 || second_derivative.call(truncated_data.size() -look_back_amount) < 0.0) &&
    #         second_derivative.call(truncated_data.size() -look_back_amount-3) >= 0.0 && (second_derivative.call(truncated_data.size() -look_back_amount-4) >= 0.0 || second_derivative.call(truncated_data.size() -look_back_amount-5) >= 0.0)

    # accel_crosses_zero_simple = second_derivative.call(truncated_data.size()-look_back_amount - 1) >= 0.0 && second_derivative.call(truncated_data.size()-look_back_amount) < 0.0

    # puts [second_derivative.call(truncated_data.size()-look_back_amount - 1), second_derivative.call(truncated_data.size()-look_back_amount)].inspect
    # puts "#{second_derivative_sunsettiness_wrt_time}; val: #{second_derivative.call(truncated_data.size()-look_back_amount-2)}  "
    # puts "dc_value: #{dc_value} #{dc_value > DC_CONSTANT ? "okay" : "too low"} #{accel_crosses_zero_simple ? "crossed zero" : ""}"
    # # puts [second_derivative.call(truncated_data.size() -look_back_amount-3), second_derivative.call(truncated_data.size() -look_back_amount-4), second_derivative.call(truncated_data.size() -look_back_amount-5), 
    # #      second_derivative.call(truncated_data.size()-look_back_amount-2), second_derivative.call(truncated_data.size() -look_back_amount-1), second_derivative.call(truncated_data.size() -look_back_amount) ].inspect
    # puts 
    # puts "\n"
    # #the "x" value here is just the location on the timeline; at a frequency of one photo / minute (ish)
    # return (dc_value > DC_CONSTANT) && accel_crosses_zero_simple


  end
end