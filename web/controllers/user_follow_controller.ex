defmodule PhoenixChina.UserFollowController do
  use PhoenixChina.Web, :controller

  alias PhoenixChina.{User, UserFollow, Notification}

  import PhoenixChina.ViewHelpers, only: [current_user: 1]
  import PhoenixChina.Ecto.Helpers, only: [increment: 2, decrement: 2]

  plug Guardian.Plug.EnsureAuthenticated, [handler: PhoenixChina.GuardianErrorHandler]

  def create(conn, %{"user_username" => username}) do
    current_user = current_user(conn)
    to_user = User |> Repo.get_by!(username: username)

    params = %{:user_id => current_user.id, :to_user_id => to_user.id}
    changeset = UserFollow.changeset(%UserFollow{}, params)

    case Repo.insert(changeset) do
      {:ok, _user_follow} ->
        to_user |> increment(:follower_count)
        current_user |> increment(:followed_count)

        notification_html = Notification.render "user_follow.html",
          conn: conn,
          user: current_user

        Notification.publish(
          "user_follow",
          to_user.id,
          current_user.id,
          current_user.id,
          notification_html
        )

        to_user |> increment(:unread_notifications_count)

        conn
        |> put_flash(:info, "关注成功.")
        |> redirect(to: user_path(conn, :show, username))
      {:error, _changeset} ->
        conn
        |> put_flash(:info, "关注失败.")
        |> redirect(to: user_path(conn, :show, username))
    end
  end

  def delete(conn, %{"user_username" => username}) do
    current_user = current_user(conn)
    to_user = User |> Repo.get_by!(username: username)

    UserFollow
    |> Repo.get_by!(user_id: current_user.id, to_user_id: to_user.id)
    |> Repo.delete!

    to_user |> decrement(:follower_count)
    current_user |> decrement(:followed_count)

    conn
    |> put_flash(:info, "取消关注成功.")
    |> redirect(to: user_path(conn, :show, username))
  end
end
