class ReservationsController < ApplicationController
  before_action :authenticate_user!, except: [:notify]
  protect_from_forgery except: [:notify, :show_trips] # allow PayPal to redirect back to page

  def create
    if current_user != room.user
      @reservation = current_user.reservations.create(reservation_params)

      if @reservation
        # Payment request to PayPal
        values = {
          business: ENV["pp_facilitator_email"],
          cmd: '_xclick',
          upload: 1,
          notify_url: ENV["ngrok_notify_link"],
          amount: @reservation.total,
          item_name: @reservation.room.listing_name,
          item_number: @reservation.id,
          quantity: '1',
          return: ENV["ngrok_return_link"]
        }

        redirect_to 'https://www.sandbox.paypal.com/cgi-bin/webscr?' + values.to_query
      else
        redirect_to @reservation.room, alert: 'Sorry, but something went wrong.'
      end
    else
      redirect_to @reservation.room, notice: "Sorry, but you can't book your own room."
    end
  end

  def notify
    params.permit!
    status = params[:payment_status]

    reservation = Reservation.find(params[:item_number])

    if status == 'Completed'
      reservation.update_attributes status: true
    else
      reservation.destroy
    end

    render nothing: true
  end

  def preload
    room = Room.find(params[:room_id])
    today = Date.today
    reservations = room.reservations.where('start_date >= ? OR end_date >= ?', today, today)

    render json: reservations
  end

  def preview
    start_date = Date.parse(params[:start_date])
    end_date = Date.parse(params[:end_date])

    output = {
      conflict: is_conflict(start_date, end_date)
    }

    render json: output
  end

  def show_trips
    @trips = current_user.reservations.where('status = ?', true)
  end

  def show_reservations
    @rooms = current_user.rooms
  end

  private

  def is_conflict(start_date, end_date)
    room = Room.find(params[:room_id])

    check = room.reservations.where("? < start_date AND end_date < ?", start_date, end_date)
    check.size > 0? true : false
  end

  def reservation_params
    params.require(:reservation).permit(:start_date, :end_date, :price, :total, :room_id)
  end
end