package types

/*
TODO: UserID はデータベース固有のものではなく、Supabase と連携したIDを使いたいので、database package の外に出した方が良いかも。
*/
type UserID string

type UserItem struct {
	// TODO: 適切なデータ構造を設計する
	// shoppint_list_id とかは少なくとも必要と思われる
	UserID       UserID `dynamodbav:"user_id" json:"user_id"`
	UserEmail    string `dynamodbav:"user_email" json:"user_email"`
	ConnectionID string `dynamodbav:"connection_id" json:"connection_id"`
}

func (userID UserID) ToString() string {
	return string(userID)
}
